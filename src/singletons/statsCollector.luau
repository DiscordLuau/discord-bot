local logger = require("../objects/logger")

local database = require("../singletons/database")

local procStats = require("../utilities/procStats")

local INTERVAL = 10

local StatsCollector = {}

StatsCollector.Priority = 0

local function collect()
	local ok, err = pcall(function()
		local stats = procStats()

		database.db:exec(
			`INSERT INTO process_snapshots (time, resident_set_size_in_kb, cpu_time_in_seconds, memory_used_in_kb) VALUES ({os.time()}, {stats.residentSetSizeKb}, {stats.cpuSeconds}, {stats.memoryUsedKb})`
		)
	end)

	if not ok then
		logger:warn(`statsCollector: snapshot failed: {err}`)
	end
end

local function scheduleNext()
	zune.task.delay(INTERVAL, function()
		collect()
		scheduleNext()
	end)
end

function StatsCollector:onReady()
	logger:info(`StatsCollector starting - collecting every {INTERVAL}s`)

	collect()

	scheduleNext()
end

export type StatsCollector = typeof(StatsCollector)

return StatsCollector
