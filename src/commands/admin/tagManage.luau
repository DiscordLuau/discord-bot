local builders = require("../../../luau_packages/builders")

local commands = require("../../singletons/commands")
local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")

local binder = require("../../utilities/binder")
local handleInteraction = require("../../utilities/handleInteraction")
local respondCommand = require("../../utilities/respondCommand")
local tags = require("../../utilities/tags")

local MODAL_CREATE_ID = "tag_create"
local MODAL_EDIT_PREFIX = "tag_edit:"
local MODAL_FIELD_NAME = "name"
local MODAL_FIELD_CONTENT = "content"

local function formatList(): string
	local all = tags.getAll()

	if #all == 0 then
		return "No tags exist yet."
	end

	local names = {}

	for _, tag in all do
		table.insert(names, `\`{tag.name}\``)
	end

	return "**Tags:** " .. table.concat(names, ", ")
end

local function makeActionRow(textInput: any)
	return builders.message.components.actionRow
		.new()
		:addComponent(textInput)
		:build()
end

local nameOption = builders.interaction.option
	.new()
	:setType("String")
	:setName("name")
	:setDescription("The tag name")
	:setRequired(true)
	:build()

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("manage-tags")
	:setDescription("Manage tags")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:setDefaultMemberPermissions(8)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("create")
			:setDescription("Create a new tag via modal")
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("edit")
			:setDescription("Edit an existing tag via modal")
			:addOption(nameOption)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("delete")
			:setDescription("Permanently delete a tag")
			:addOption(nameOption)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("list")
			:setDescription("List all available tags")
			:build()
	)
	:build()

return function()
	local addToBinder, cleanup = binder()

	addToBinder(discordBot.onCommandInteraction:listen(function(interaction)
		if interaction.data.name ~= "manage-tags" then
			return
		end

		handleInteraction(interaction, { "admin" }, function()
			local subcommand = interaction.data.options[1]

			if not subcommand then
				logger:warn("Received /manage-tags interaction with no subcommand")

				interaction:messageAsync(respondCommand("No subcommand provided.")):poll()

				return
			end

			if subcommand.name == "create" then
				local modal = builders.message.components.modal
					.new()
					:setCustomId(MODAL_CREATE_ID)
					:setTitle("Create Tag")
					:setComponents({
						makeActionRow(
							builders.message.components.textInput
								.new()
								:setCustomId(MODAL_FIELD_NAME)
								:setStyle("Short")
								:setLabel("Tag name")
								:setPlaceholder("install")
								:setIsRequired(true)
								:build()
						),
						makeActionRow(
							builders.message.components.textInput
								.new()
								:setCustomId(MODAL_FIELD_CONTENT)
								:setStyle("Paragraph")
								:setLabel("Tag content")
								:setPlaceholder("The content that will be sent when this tag is used.")
								:setIsRequired(true)
								:build()
						),
					})
					:build()

				interaction:modalAsync(modal):poll()

			elseif subcommand.name == "edit" then
				local nameOpt = subcommand.options and subcommand.options[1]
				local tagName: string = nameOpt and nameOpt.value

				local foundTag = tags.get(tagName)

				if not foundTag then
					interaction:messageAsync(respondCommand(`No tag found with name \`{tagName}\`.`)):poll()

					return
				end

				local modal = builders.message.components.modal
					.new()
					:setCustomId(`{MODAL_EDIT_PREFIX}{foundTag.name}`)
					:setTitle(`Edit Tag: {foundTag.name}`)
					:setComponents({
						makeActionRow(
							builders.message.components.textInput
								.new()
								:setCustomId(MODAL_FIELD_CONTENT)
								:setStyle("Paragraph")
								:setLabel("Tag content")
								:setValue(foundTag.content)
								:setIsRequired(true)
								:build()
						),
					})
					:build()

				interaction:modalAsync(modal):poll()

			elseif subcommand.name == "delete" then
				local nameOpt = subcommand.options and subcommand.options[1]
				local tagName: string = nameOpt and nameOpt.value

				if not tags.exists(tagName) then
					interaction:messageAsync(respondCommand(`No tag found with name \`{tagName}\`.`)):poll()

					return
				end

				tags.delete(tagName)

				logger:info(`Deleted tag "{tagName}"`)

				interaction:messageAsync(respondCommand(`Deleted tag \`{tagName}\`.`)):poll()

			elseif subcommand.name == "list" then
				interaction:messageAsync(respondCommand(formatList())):poll()

			else
				logger:warn(`Unknown /manage-tags subcommand '{subcommand.name}'`)

				interaction:messageAsync(respondCommand(`Unknown subcommand \`{subcommand.name}\`.`)):poll()
			end
		end)
	end))

	addToBinder(discordBot.onModalInteraction:listen(function(modal)
		local isCreate = modal.data.customId == MODAL_CREATE_ID
		local isEdit = modal.data.customId:find(MODAL_EDIT_PREFIX, 1, true) == 1

		if not isCreate and not isEdit then
			return
		end

		handleInteraction(modal, { "admin" }, function()
			local content = modal:getContent(MODAL_FIELD_CONTENT) or ""

			if content == "" then
				modal:messageAsync(respondCommand("Tag content cannot be empty.")):poll()

				return
			end

			if isCreate then
				local name = (modal:getContent(MODAL_FIELD_NAME) or ""):lower():match("^%s*(.-)%s*$")

				if name == "" then
					modal:messageAsync(respondCommand("Tag name cannot be empty.")):poll()

					return
				end

				if tags.exists(name) then
					modal:messageAsync(respondCommand(`A tag with the name \`{name}\` already exists.`)):poll()

					return
				end

				tags.create(name, content)

				logger:info(`Created tag "{name}"`)

				modal:messageAsync(respondCommand(`Created tag \`{name}\`.`)):poll()

			else
				local tagName = modal.data.customId:sub(#MODAL_EDIT_PREFIX + 1)

				if not tags.exists(tagName) then
					modal:messageAsync(respondCommand(`Tag \`{tagName}\` no longer exists.`)):poll()

					return
				end

				tags.update(tagName, content)

				logger:info(`Edited tag "{tagName}"`)

				modal:messageAsync(respondCommand(`Updated tag \`{tagName}\`.`)):poll()
			end
		end)
	end))

	commands:registerAsync(COMMAND_OBJECT)

	return cleanup
end
