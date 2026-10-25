local builders = require("../../../luau_packages/builders")

local music = require("../../singletons/music")

local musicGuard = require("../../utilities/musicGuard")
local musicMessages = require("../../utilities/musicMessages")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("pause")
	:setDescription("Pause the song that is playing")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 2, per = "user" } },

	execute = function(interaction)
		local session = musicGuard(interaction, "pause")

		if session then
			local track = session.current
			local paused = music:pause()
			local reply = if paused and track
				then `Paused {musicMessages.trackLine(track)}`
				else "It's already paused, or no song is playing yet"

			interaction:messageAsync(respondCommand(reply, not paused)):poll()
		end
	end,
}
