local builders = require("../../../luau_packages/builders")

local music = require("../../singletons/music")

local musicGuard = require("../../utilities/musicGuard")
local musicMessages = require("../../utilities/musicMessages")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("nowplaying")
	:setDescription("Show the song that is playing")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 2, per = "user" } },

	execute = function(interaction)
		local session = musicGuard(interaction, "nowplaying")

		if session then
			local track, elapsedSeconds = music:nowPlaying()
			local reply = if track
				then musicMessages.nowPlayingStatus(track, elapsedSeconds, session.player.paused)
				else "Nothing is playing right now"

			interaction:messageAsync(respondCommand(reply, not track)):poll()
		end
	end,
}
