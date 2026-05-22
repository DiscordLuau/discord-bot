local bot = require("@self/objects/discordBot")
local logger = require("@self/objects/logger")

local lifecycle = require("@self/utilities/lifecycle")

local SINGLETONS = {
	require("@self/singletons/logSink"),
	require("@self/singletons/database"),
	require("@self/singletons/commands"),
	require("@self/singletons/connectionStats"),
	require("@self/singletons/statsCollector"),
	require("@self/singletons/presence"),
	require("@self/singletons/wordReactor"),
	require("@self/singletons/autoResponder"),
	require("@self/singletons/staleThreadBumper"),
	require("@self/singletons/welcomer"),
}

logger:info(`Loaded {#SINGLETONS} singleton(s) - waiting for all shards to be ready`)

bot.onAllShardsReady:listenOnce(function()
	logger:info("All shards ready - running onReady lifecycle")

	lifecycle(SINGLETONS, "onReady")

	logger:info("onReady lifecycle complete")
end)

logger:info("Connecting bot")

bot:connectAsync():await()

logger:info("Bot connected")
