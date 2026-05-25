local logger = require("../../objects/logger")

local autoresponses = require("../../utilities/autoresponses")
local checkPermissions = require("../../utilities/checkPermissions")
local parseCommaSeparated = require("../../utilities/parseCommaSeparated")
local permissionGuard = require("../../utilities/permissionGuard")
local respondCommand = require("../../utilities/respondCommand")
local truncate = require("../../utilities/truncate")

local builders = require("../../../luau_packages/builders")

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

local function makeActionRow(textInput: any)
	return builders.message.components.actionRow.new():addComponent(textInput):build()
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

return {
	command = COMMAND_OBJECT,
	category = "Admin",
	cooldown = { { seconds = 5, per = "user" } },
	guards = { permissionGuard({ "admin" }) },

	execute = function() end,

	subcommands = {
		add = {
			execute = function(interaction)
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
			end,
		},
		remove = {
			execute = function(interaction)
				local subcommand = interaction.data.options[1]

				local idOption = subcommand.options and subcommand.options[1]

				local autoResponseId: number = idOption and idOption.value

				if not autoresponses.exists(autoResponseId) then
					logger:warn(`remove: no autoresponse found with ID {autoResponseId}`)

					interaction
						:messageAsync(respondCommand(`No autoresponse found with ID {autoResponseId}.`, true))
						:poll()

					return
				end

				autoresponses.delete(autoResponseId)

				logger:info(`Deleted autoresponse ID {autoResponseId}`)

				interaction:messageAsync(respondCommand(`Removed autoresponse ID {autoResponseId}.`)):poll()
			end,
		},
		list = {
			execute = function(interaction)
				interaction:messageAsync(respondCommand(formatList())):poll()
			end,
		},
	},
	modals = {
		[MODAL_CUSTOM_ID] = function(modal)
			if not checkPermissions(modal, { "admin" }) then
				logger:warn(
					`autoresponse_add modal: permission denied for user {modal.member and modal.member.user and modal.member.user.id}`
				)

				modal:messageAsync(respondCommand("You don't have permission to use this command.", true)):poll()

				return
			end

			local rawKeyphrases = modal:getContent(MODAL_FIELD_KEYPHRASES) or ""
			local content = modal:getContent(MODAL_FIELD_CONTENT) or ""
			local rawReply = (modal:getContent(MODAL_FIELD_REPLY) or "yes"):lower():match("^%s*(.-)%s*$")
			local shouldReply = rawReply ~= "no"
			local keyphrases = parseCommaSeparated(rawKeyphrases)

			if #keyphrases == 0 then
				logger:warn("autoresponse_add modal: submitted with no keyphrases")

				modal:messageAsync(respondCommand("At least one keyphrase is required.", true)):poll()

				return
			end

			if content == "" then
				logger:warn("autoresponse_add modal: submitted with empty content")

				modal:messageAsync(respondCommand("Response content cannot be empty.", true)):poll()

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
		end,
	},
}
