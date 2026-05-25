local respondCommand = require("../../utilities/respondCommand")

local builders = require("../../../luau_packages/builders")

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

return {
	command = COMMAND_OBJECT,
	category = "Utility",
	cooldown = { { seconds = 3, per = "user" } },
	execute = function(interaction)
		interaction:messageAsync(respondCommand("Pong!")):poll()
	end,
}
