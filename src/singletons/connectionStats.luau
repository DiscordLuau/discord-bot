local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local ConnectionStats = {}

ConnectionStats.Priority = 0
ConnectionStats.ConnectedAt = 0
ConnectionStats.ReconnectCount = 0
ConnectionStats.ShardCount = 0

function ConnectionStats:onReady()
	self.ConnectedAt = os.time()

	logger:info(`Connection stats tracking started`)

	discordBot.onReady:listen(function()
		self.ShardCount += 1
	end)

	discordBot.onShardReconnected:listen(function(shardId)
		self.ReconnectCount += 1

		logger:info(`Shard {shardId} reconnected (total reconnects: {self.ReconnectCount})`)
	end)
end

export type connectionStats = typeof(ConnectionStats)

return ConnectionStats
