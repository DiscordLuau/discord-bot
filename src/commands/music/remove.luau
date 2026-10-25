local builders = require("../../../luau_packages/builders")

local music = require("../../singletons/music")

local musicGuard = require("../../utilities/musicGuard")
local musicMessages = require("../../utilities/musicMessages")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("remove")
	:setDescription("Remove an upcoming song from the queue")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:addOption(
		builders.interaction.option
			.new()
			:setType("Integer")
			:setName("position")
			:setDescription("The song's position in /queue")
			:setRequired(true)
			:setMinValue(1)
			:build()
	)
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 2, per = "user" } },

	execute = function(interaction)
		local session = musicGuard(interaction, "remove")

		if session then
			local position = interaction:getInteger("position") or 0
			local removed = music:remove(position)
			local reply = if removed
				then `Removed {musicMessages.trackLine(removed)}`
				else `There's no song at position {position}`

			interaction:messageAsync(respondCommand(reply, not removed)):poll()
		end
	end,
}
