local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local ConnectionStats = {}

ConnectionStats.Priority = 0
ConnectionStats.ConnectedAt = 0
ConnectionStats.LastConnectedAt = 0
ConnectionStats.ReconnectCount = 0
ConnectionStats.ShardCount = 0

function ConnectionStats:onReady()
	local now = os.time()

	self.ConnectedAt = now
	self.LastConnectedAt = now

	logger:info(`Connection stats tracking started`)

	discordBot.onAllShardsReady:listen(function()
		self.ShardCount = #discordBot.state.webSocketManager.shards
		self.LastConnectedAt = os.time()
	end)

	discordBot.onShardReconnected:listen(function(shardId)
		self.ReconnectCount += 1
		self.LastConnectedAt = os.time()

		logger:info(`Shard {shardId} reconnected (total reconnects: {self.ReconnectCount})`)
	end)
end

export type ConnectionStats = typeof(ConnectionStats) & {
	Priority: number,
	ConnectedAt: number,
	LastConnectedAt: number,
	ReconnectCount: number,
	ShardCount: number,
}

return ConnectionStats
