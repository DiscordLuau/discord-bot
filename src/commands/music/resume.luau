local builders = require("../../../luau_packages/builders")

local music = require("../../singletons/music")

local musicGuard = require("../../utilities/musicGuard")
local musicMessages = require("../../utilities/musicMessages")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("resume")
	:setDescription("Resume the paused song")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 2, per = "user" } },

	execute = function(interaction)
		local session = musicGuard(interaction, "resume")

		if session then
			local track = session.current
			local resumed = music:resume()
			local reply = if resumed and track then `Resumed {musicMessages.trackLine(track)}` else "It isn't paused"

			interaction:messageAsync(respondCommand(reply, not resumed)):poll()
		end
	end,
}
