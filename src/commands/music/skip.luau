local builders = require("../../../luau_packages/builders")

local music = require("../../singletons/music")

local musicGuard = require("../../utilities/musicGuard")
local musicMessages = require("../../utilities/musicMessages")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("skip")
	:setDescription("Skip the song that is playing")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 2, per = "user" } },

	execute = function(interaction)
		local session = musicGuard(interaction, "skip")

		if session then
			local track = session.current
			local skipped = music:skip()
			local reply = if skipped and track
				then `Skipped {musicMessages.trackLine(track)}`
				else "Nothing is playing right now"

			interaction:messageAsync(respondCommand(reply, not skipped)):poll()
		end
	end,
}
