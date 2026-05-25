local bot = require("@self/objects/discordBot")
local commands = require("@self/objects/commands")
local logger = require("@self/objects/logger")

local config = require("@self/config")
local lifecycle = require("@self/utilities/lifecycle")

local SINGLETONS = {
	require("@self/singletons/logSink"),
	require("@self/singletons/database"),
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

	logger:info("Loading commands")
	commands:load("src/commands")
	logger:info("Registering commands with Discord")

	local registerResult = commands:registerGuildAsync(config.guildId):await()

	if registerResult:isErr() then
		logger:warn(`Command registration failed: {registerResult:unwrapErr()}`)
	else
		logger:info("Commands registered successfully")
	end

	logger:info("onReady lifecycle complete")
end)

logger:info("Connecting bot")

bot:connectAsync():await()

logger:info("Bot connected")
