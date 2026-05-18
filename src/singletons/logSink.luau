local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local database = require("../singletons/database")

local LEVEL_ORDER = { "Debug", "Info", "Notice", "Warn", "Error", "Critical", "Alert", "Emergency" }

local LogSink = {}

LogSink.Priority = 0
LogSink.CriticalCount = 0

local function levelIndex(level: string): number
	return table.find(LEVEL_ORDER, level) or 0
end

local function capture(message: string)
	local rawLevel = message:match("%[(%u+)%]:")
	local level = if rawLevel then rawLevel:sub(1, 1) .. rawLevel:sub(2):lower() else "Debug"
	local index = levelIndex(level)

	if index >= levelIndex("Critical") then
		LogSink.CriticalCount += 1
	end

	local escaped = message:gsub("'", "''")

	database.db:exec(
		`INSERT INTO logs (level, level_index, message, time) VALUES ('{level}', {index}, '{escaped}', {os.time()})`
	)
end

local function sink(message: string)
	print(message)
	capture(message)
end

local function applyShardSinks()
	for _, shard in discordBot.state.webSocketManager.shards do
		shard.logger:setSink(sink)
	end
end

function LogSink:onReady()
	logger:setSink(sink)
	discordBot.logger:setSink(sink)
	discordBot.state.webSocketManager.logger:setSink(sink)
	discordBot.state.rest.logger:setSink(sink)

	applyShardSinks()

	discordBot.onReady:listen(function()
		applyShardSinks()
	end)
end

function LogSink:query(options: QueryOptions): { string }
	local minIndex = levelIndex(options.level or "Debug")
	local cutoff = options.after or 0
	local limit = options.count or 15

	local rows = database.db
		:query(
			`SELECT message FROM logs WHERE level_index >= {minIndex} AND time >= {cutoff} ORDER BY id DESC LIMIT {limit}`
		)
		:all() :: any

	local messages = {}

	for index = #rows, 1, -1 do
		table.insert(messages, rows[index].message)
	end

	return messages
end

export type QueryOptions = {
	level: string?,
	after: number?,
	count: number?,
}

export type LogSink = typeof(LogSink) & {
	Priority: number,
	CriticalCount: number,
}

return LogSink
