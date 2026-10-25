local builders = require("../../../luau_packages/builders")

local music = require("../../singletons/music")

local musicGuard = require("../../utilities/musicGuard")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("stop")
	:setDescription("Stop the music, clear the queue and leave voice")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 2, per = "user" } },

	execute = function(interaction)
		local session = musicGuard(interaction, "stop")

		if session then
			local channelId = session.channelId

			interaction:messageAsync(respondCommand(`Stopped and left <#{channelId}>`)):poll()
			music:stop()
		end
	end,
}
