local builders = require("../../../luau_packages/builders")

local music = require("../../singletons/music")

local musicGuard = require("../../utilities/musicGuard")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("shuffle")
	:setDescription("Shuffle the songs coming up")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 2, per = "user" } },

	execute = function(interaction)
		local session = musicGuard(interaction, "shuffle")

		if session then
			local count = music:shuffle()
			local reply = if count >= 2 then `Shuffled {count} songs` else "There's nothing to shuffle"

			interaction:messageAsync(respondCommand(reply, count < 2)):poll()
		end
	end,
}
