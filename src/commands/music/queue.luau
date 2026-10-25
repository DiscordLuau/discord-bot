local builders = require("../../../luau_packages/builders")

local music = require("../../singletons/music")

local musicGuard = require("../../utilities/musicGuard")
local musicMessages = require("../../utilities/musicMessages")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("queue")
	:setDescription("Show the songs coming up")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:addOption(
		builders.interaction.option
			.new()
			:setType("Integer")
			:setName("page")
			:setDescription("Which page of the queue to show")
			:setMinValue(1)
			:build()
	)
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 2, per = "user" } },

	execute = function(interaction)
		local session = musicGuard(interaction, "queue")

		if session then
			local page = interaction:getInteger("page") or 1
			local queuePage = music:queuePage(page)
			local message = if queuePage then musicMessages.queuePage(queuePage) else musicMessages.queueClosed()

			interaction:messageAsync(message):poll()
		end
	end,
}
