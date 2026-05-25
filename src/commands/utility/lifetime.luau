local builders = require("../../../luau_packages/builders")

local connectionStats = require("../../singletons/connectionStats")
local logSink = require("../../singletons/logSink")

local formatDuration = require("../../utilities/formatDuration")
local respondCommand = require("../../utilities/respondCommand")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("lifetime")
	:setDescription("Show bot connection stats")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Utility",
	cooldown = { { seconds = 5, per = "user" } },
	execute = function(interaction)
		local now = os.time()
		local uptime = now - connectionStats.ConnectedAt
		local sessionUptime = now - connectionStats.LastConnectedAt
		local shards = connectionStats.ShardCount
		local reconnects = connectionStats.ReconnectCount
		local criticals = logSink.CriticalCount
		local reconnectLabel = reconnects == 1 and "Reconnection" or "Reconnections"
		local criticalLabel = criticals == 1 and "Critical Error" or "Critical Errors"
		local shardLabel = shards == 1 and "Shard" or "Shards"

		local response =
			`Uptime: **{formatDuration(uptime)}** · Session: **{formatDuration(sessionUptime)}** · **{reconnects}** {reconnectLabel} · **{criticals}** {criticalLabel} · **{shards}** {shardLabel}`

		interaction:messageAsync(respondCommand(response)):poll()
	end,
}
