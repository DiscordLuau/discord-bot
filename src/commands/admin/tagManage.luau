local builders = require("../../../luau_packages/builders")

local logger = require("../../objects/logger")

local checkPermissions = require("../../utilities/checkPermissions")
local permissionGuard = require("../../utilities/permissionGuard")
local respondCommand = require("../../utilities/respondCommand")

local tags = require("../../utilities/tags")

local MODAL_CREATE_ID = "tag_create"
local MODAL_EDIT_PREFIX = "tag_edit:"
local MODAL_FIELD_NAME = "name"
local MODAL_FIELD_CONTENT = "content"

local function formatList(): string
	local allTags = tags.getAll()

	if #allTags == 0 then
		return "No tags exist yet."
	end

	local names = {}

	for _, tag in allTags do
		table.insert(names, `\`{tag.name}\``)
	end

	return "**Tags:** " .. table.concat(names, ", ")
end

local function makeActionRow(textInput: any)
	return builders.message.components.actionRow.new():addComponent(textInput):build()
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

return {
	command = COMMAND_OBJECT,
	category = "Admin",
	cooldown = { { seconds = 5, per = "user" } },
	guards = { permissionGuard({ "admin" }) },

	execute = function() end,

	subcommands = {
		create = {
			execute = function(interaction)
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
			end,
		},
		edit = {
			execute = function(interaction)
				local subcommand = interaction.data.options[1]

				local nameOption = subcommand.options and subcommand.options[1]

				local tagName: string = nameOption and nameOption.value

				local foundTag = tags.get(tagName)

				if not foundTag then
					logger:warn(`edit: no tag found with name "{tagName}"`)

					interaction:messageAsync(respondCommand(`No tag found with name \`{tagName}\`.`, true)):poll()

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
			end,
		},
		delete = {
			execute = function(interaction)
				local subcommand = interaction.data.options[1]
				local nameOption = subcommand.options and subcommand.options[1]
				local tagName: string = nameOption and nameOption.value

				if not tags.exists(tagName) then
					logger:warn(`delete: no tag found with name "{tagName}"`)

					interaction:messageAsync(respondCommand(`No tag found with name \`{tagName}\`.`, true)):poll()

					return
				end

				tags.delete(tagName)

				logger:info(`Deleted tag "{tagName}"`)

				interaction:messageAsync(respondCommand(`Deleted tag \`{tagName}\`.`)):poll()
			end,
		},
		list = {
			execute = function(interaction)
				interaction:messageAsync(respondCommand(formatList())):poll()
			end,
		},
	},
	modals = {
		[MODAL_CREATE_ID] = function(modal)
			if not checkPermissions(modal, { "admin" }) then
				logger:warn(
					`tag_create modal: permission denied for user {modal.member and modal.member.user and modal.member.user.id}`
				)

				modal:messageAsync(respondCommand("You don't have permission to use this command.", true)):poll()

				return
			end

			local content = modal:getContent(MODAL_FIELD_CONTENT) or ""

			if content == "" then
				logger:warn("tag_create modal: submitted with empty content")

				modal:messageAsync(respondCommand("Tag content cannot be empty.", true)):poll()

				return
			end

			local name = (modal:getContent(MODAL_FIELD_NAME) or ""):lower():match("^%s*(.-)%s*$")

			if name == "" then
				logger:warn("tag_create modal: submitted with empty name")

				modal:messageAsync(respondCommand("Tag name cannot be empty.", true)):poll()

				return
			end

			if tags.exists(name) then
				logger:warn(`tag_create modal: tag "{name}" already exists`)

				modal:messageAsync(respondCommand(`A tag with the name \`{name}\` already exists.`, true)):poll()

				return
			end

			tags.create(name, content)

			logger:info(`Created tag "{name}"`)

			modal:messageAsync(respondCommand(`Created tag \`{name}\`.`)):poll()
		end,
		[`{MODAL_EDIT_PREFIX}*`] = function(modal)
			if not checkPermissions(modal, { "admin" }) then
				logger:warn(
					`tag_edit modal: permission denied for user {modal.member and modal.member.user and modal.member.user.id}`
				)

				modal:messageAsync(respondCommand("You don't have permission to use this command.", true)):poll()

				return
			end

			local content = modal:getContent(MODAL_FIELD_CONTENT) or ""

			if content == "" then
				logger:warn("tag_edit modal: submitted with empty content")

				modal:messageAsync(respondCommand("Tag content cannot be empty.", true)):poll()

				return
			end

			local tagName = modal.data.customId:sub(#MODAL_EDIT_PREFIX + 1)

			if not tags.exists(tagName) then
				logger:warn(`tag_edit modal: tag "{tagName}" no longer exists`)

				modal:messageAsync(respondCommand(`Tag \`{tagName}\` no longer exists.`, true)):poll()

				return
			end

			tags.update(tagName, content)

			logger:info(`Edited tag "{tagName}"`)

			modal:messageAsync(respondCommand(`Updated tag \`{tagName}\`.`)):poll()
		end,
	},
}
