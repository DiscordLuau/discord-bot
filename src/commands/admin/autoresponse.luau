local builders = require("../../../luau_packages/builders")

local commands = require("../../singletons/commands")
local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")

local autoresponses = require("../../utilities/autoresponses")
local binder = require("../../utilities/binder")
local handleInteraction = require("../../utilities/handleInteraction")
local parseCommaSeparated = require("../../utilities/parseCommaSeparated")
local respondCommand = require("../../utilities/respondCommand")
local truncate = require("../../utilities/truncate")

local MODAL_CUSTOM_ID = "autoresponse_add"
local MODAL_FIELD_KEYPHRASES = "keyphrases"
local MODAL_FIELD_CONTENT = "content"
local MODAL_FIELD_REPLY = "reply"

local function formatList(): string
	local rows = autoresponses.getAll()

	if #rows == 0 then
		return "No autoresponses exist yet."
	end

	local lines = { "**All Autoresponses**", "" }

	for _, row in rows do
		local keyphrases: { string } = zune.serde.json.decode(row.keyphrases :: string)
		local keyphraseList = table.concat(keyphrases, ", ")
		local replyLabel = if row.reply == 1 then "reply" else "channel message"
		local content = row.content :: string

		table.insert(lines, `**ID {row.id}** [{replyLabel}] - keyphrases: \`{keyphraseList}\``)
		table.insert(lines, `> {truncate(content, 80)}`)
		table.insert(lines, "")
	end

	return table.concat(lines, "\n"):gsub("\n$", "")
end

local idOption = builders.interaction.option
	.new()
	:setType("Integer")
	:setName("id")
	:setDescription("The ID of the autoresponse (use /manage-autoresponse list to see IDs)")
	:setRequired(true)
	:setMinValue(1)
	:build()

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("manage-autoresponse")
	:setDescription("Manage autoresponses")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:setDefaultMemberPermissions(8)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("add")
			:setDescription("Add a new autoresponse via modal")
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("remove")
			:setDescription("Permanently remove an autoresponse")
			:addOption(idOption)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("list")
			:setDescription("List all autoresponses")
			:build()
	)
	:build()

local function makeActionRow(textInput: any)
	return builders.message.components.actionRow.new():addComponent(textInput):build()
end

return function()
	local addToBinder, cleanup = binder()

	addToBinder(discordBot.onCommandInteraction:listen(function(interaction)
		if interaction.data.name ~= "manage-autoresponse" then
			return
		end

		handleInteraction(interaction, { "admin" }, function()
			local subcommand = interaction.data.options[1]

			if not subcommand then
				logger:warn("Received /manage-autoresponse interaction with no subcommand")

				interaction:messageAsync(respondCommand("No subcommand provided.")):poll()

				return
			end

			if subcommand.name == "add" then
				local modal = builders.message.components.modal
					.new()
					:setCustomId(MODAL_CUSTOM_ID)
					:setTitle("Add Autoresponse")
					:setComponents({
						makeActionRow(
							builders.message.components.textInput
								.new()
								:setCustomId(MODAL_FIELD_KEYPHRASES)
								:setStyle("Short")
								:setLabel("Keyphrases (comma-separated)")
								:setPlaceholder("how do I install, installation guide, getting started")
								:setIsRequired(true)
								:build()
						),
						makeActionRow(
							builders.message.components.textInput
								.new()
								:setCustomId(MODAL_FIELD_CONTENT)
								:setStyle("Paragraph")
								:setLabel("Response content")
								:setPlaceholder("The response that will be sent when a keyphrase is matched.")
								:setIsRequired(true)
								:build()
						),
						makeActionRow(
							builders.message.components.textInput
								.new()
								:setCustomId(MODAL_FIELD_REPLY)
								:setStyle("Short")
								:setLabel("Reply to message? (yes / no)")
								:setPlaceholder("yes")
								:setValue("yes")
								:setIsRequired(true)
								:build()
						),
					})
					:build()

				interaction:modalAsync(modal):poll()
			elseif subcommand.name == "remove" then
				local idOpt = subcommand.options and subcommand.options[1]
				local autoResponseId: number = idOpt and idOpt.value

				if not autoresponses.exists(autoResponseId) then
					interaction:messageAsync(respondCommand(`No autoresponse found with ID {autoResponseId}.`)):poll()

					return
				end

				autoresponses.delete(autoResponseId)

				logger:info(`Deleted autoresponse ID {autoResponseId}`)

				interaction:messageAsync(respondCommand(`Removed autoresponse ID {autoResponseId}.`)):poll()
			elseif subcommand.name == "list" then
				interaction:messageAsync(respondCommand(formatList())):poll()
			else
				logger:warn(`Unknown /manage-autoresponse subcommand '{subcommand.name}'`)

				interaction:messageAsync(respondCommand(`Unknown subcommand \`{subcommand.name}\`.`)):poll()
			end
		end)
	end))

	addToBinder(discordBot.onModalInteraction:listen(function(modal)
		if modal.data.customId ~= MODAL_CUSTOM_ID then
			return
		end

		handleInteraction(modal, { "admin" }, function()
			local rawKeyphrases = modal:getContent(MODAL_FIELD_KEYPHRASES) or ""
			local content = modal:getContent(MODAL_FIELD_CONTENT) or ""
			local rawReply = (modal:getContent(MODAL_FIELD_REPLY) or "yes"):lower():match("^%s*(.-)%s*$")
			local shouldReply = rawReply ~= "no"

			local keyphrases = parseCommaSeparated(rawKeyphrases)

			if #keyphrases == 0 then
				modal:messageAsync(respondCommand("At least one keyphrase is required.")):poll()

				return
			end

			if content == "" then
				modal:messageAsync(respondCommand("Response content cannot be empty.")):poll()

				return
			end

			local newId = autoresponses.create(keyphrases, content, shouldReply)

			logger:info(`Added autoresponse ID {newId} with {#keyphrases} keyphrase(s) (reply: {shouldReply})`)

			local replyLabel = if shouldReply then "reply" else "channel message"

			modal
				:messageAsync(
					respondCommand(
						`Added autoresponse ID {newId} as a {replyLabel} matching: \`{table.concat(keyphrases, ", ")}\``
					)
				)
				:poll()
		end)
	end))

	commands:registerAsync(COMMAND_OBJECT)

	return cleanup
end
