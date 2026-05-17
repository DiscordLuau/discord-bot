local builders = require("../../luau_packages/builders")

local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local Presence = {}

Presence.Priority = 0

function Presence:onReady()
	local presence = builders.presence
		.new()
		:setStatus("DoNotDisturb")
		:addActivity(builders.activity.new():setActivityName("🎮"):setActivityType("Watching"):build())
		:build()

	discordBot:setPresenceAsync(presence):poll()

	logger:info("Presence set to DND")
end

export type Presence = typeof(Presence)

return Presence
