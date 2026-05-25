local logger = require("../../objects/logger")

local respondCommand = require("../../utilities/respondCommand")
local respondMessage = require("../../utilities/respondMessage")
local tags = require("../../utilities/tags")

local builders = require("../../../luau_packages/builders")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("tag")
	:setDescription("Send a tag in the channel")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:addOption(
		builders.interaction.option
			.new()
			:setType("String")
			:setName("name")
			:setDescription("The tag name")
			:setRequired(true)
			:setAutocompleteEnabled(true)
			:build()
	)
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Utility",

	execute = function(interaction)
		local nameOption = interaction.data.options and interaction.data.options[1]
		local tagName: string = nameOption and nameOption.value
		local foundTag = tags.get(tagName)

		if not foundTag then
			interaction:messageAsync(respondCommand(`No tag found with name \`{tagName}\`.`, true)):poll()

			return
		end

		interaction
			:messageAsync(respondMessage({
				builders.message.components.container
					.new()
					:addComponent(builders.message.components.textDisplay.new():setContent(foundTag.content):build())
					:build(),
			}))
			:poll()
	end,

	autocomplete = function(interaction)
		local focused = interaction.data.options and interaction.data.options[1]

		if not focused then
			logger:warn("tag autocomplete received interaction with no options")

			return
		end

		if not focused.focused then
			return
		end

		local query = (focused.value or ""):lower()
		local choices = {}

		for _, tag in tags.getAll() do
			if query == "" or tag.name:lower():find(query, 1, true) then
				table.insert(choices, builders.interaction.choice.new():setName(tag.name):setValue(tag.name):build())

				if #choices == 25 then
					break
				end
			end
		end

		interaction:respondAsync(choices):poll()
	end,
}
