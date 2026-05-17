local builders = require("../../../luau_packages/builders")
local commands = require("../../singletons/commands")
local discordBot = require("../../objects/discordBot")
local binder = require("../../utilities/binder")
local handleInteraction = require("../../utilities/handleInteraction")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("ping")
	:setDescription("Replies with Pong!")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:addContext("BotDm")
	:addContext("PrivateChannel")
	:build()

return function()
	local addToBinder, cleanup = binder()

	addToBinder(discordBot.onCommandInteraction:listen(function(interaction)
		if interaction.data.name ~= "ping" then
			return
		end

		handleInteraction(interaction, {}, function()
			interaction:messageAsync(respondCommand("Pong!")):poll()
		end)
	end))

	commands:registerAsync(COMMAND_OBJECT)

	return cleanup
end
