local builders = require("../../../luau_packages/builders")

local commands = require("../../singletons/commands")
local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")

local binder = require("../../utilities/binder")
local handleInteraction = require("../../utilities/handleInteraction")
local respondCommand = require("../../utilities/respondCommand")
local respondMessage = require("../../utilities/respondMessage")
local tags = require("../../utilities/tags")

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

return function()
	local addToBinder, cleanup = binder()

	addToBinder(discordBot.onAutocompleteInteraction:listen(function(interaction)
		if interaction.data.name ~= "tag" then
			return
		end

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
	end))

	addToBinder(discordBot.onCommandInteraction:listen(function(interaction)
		if interaction.data.name ~= "tag" then
			return
		end

		handleInteraction(interaction, {}, function()
			local nameOpt = interaction.data.options and interaction.data.options[1]
			local tagName: string = nameOpt and nameOpt.value

			local foundTag = tags.get(tagName)

			if not foundTag then
				interaction:messageAsync(respondCommand(`No tag found with name \`{tagName}\`.`)):poll()

				return
			end

			interaction:messageAsync(respondMessage({
				builders.message.components.container
					.new()
					:addComponent(
						builders.message.components.textDisplay
							.new()
							:setContent(foundTag.content)
							:build()
					)
					:build(),
			})):poll()
		end)
	end))

	commands:registerAsync(COMMAND_OBJECT)

	return cleanup
end
