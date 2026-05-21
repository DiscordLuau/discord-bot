local CLOCK_TICKS_PER_SECOND = 100

local function readMemoryInformation(): { [string]: number }
	local content = zune.fs.readFileSync("/proc/meminfo")

	local result = {}

	for key, value in content:gmatch("(%w+):%s*(%d+)") do
		result[key] = tonumber(value) :: number
	end

	return result
end

local function readProcessStatus(): { [string]: number }
	local content = zune.fs.readFileSync("/proc/self/status")

	local result = {}

	for key, value in content:gmatch("(%w+):%s*(%d+)") do
		result[key] = tonumber(value) :: number
	end

	return result
end

local function readProcessStatistics(): { utime: number, stime: number, starttime: number }
	local content = zune.fs.readFileSync("/proc/self/stat")

	local afterComm = content:match("%)(.+)")

	local fields = {}

	for field in afterComm:gmatch("%S+") do
		table.insert(fields, field)
	end

	-- Positional fields after the comm column; indices per `man 5 proc`
	return {
		utime = tonumber(fields[12]) :: number,
		stime = tonumber(fields[13]) :: number,
		starttime = tonumber(fields[20]) :: number,
	}
end

local function readSystemUptime(): number
	local content = zune.fs.readFileSync("/proc/uptime")

	return tonumber(content:match("^(%S+)")) :: number
end

local function formatBytes(kilobytes: number): string
	local megabytes = kilobytes / 1024

	if megabytes >= 1024 then
		return string.format("%.2f GB", megabytes / 1024)
	end

	return string.format("%.1f MB", megabytes)
end

export type ProcStats = {
	residentSetSize: string,
	peakResidentSetSize: string,
	virtualMemory: string,
	threads: number,
	cpuSeconds: number,
	avgCpuPercent: number,
	processUptimeSeconds: number,
	residentSetSizeKb: number,
	memoryUsedKb: number,
	memoryTotalKb: number,
}

return function(): ProcStats
	local status = readProcessStatus()

	local memoryInformation = readMemoryInformation()
	local statistics = readProcessStatistics()
	local systemUptime = readSystemUptime()
	local processUptimeSeconds = systemUptime - statistics.starttime / CLOCK_TICKS_PER_SECOND
	local cpuSeconds = (statistics.utime + statistics.stime) / CLOCK_TICKS_PER_SECOND
	local avgCpuPercent = if processUptimeSeconds > 0 then (cpuSeconds / processUptimeSeconds) * 100 else 0

	local memoryTotalKb = memoryInformation.MemTotal or 0
	local memoryAvailableKb = memoryInformation.MemAvailable or 0
	local memoryUsedKb = memoryTotalKb - memoryAvailableKb

	return {
		residentSetSize = formatBytes(status.VmRSS),
		peakResidentSetSize = formatBytes(status.VmHWM),
		virtualMemory = formatBytes(status.VmSize),
		threads = status.Threads,
		cpuSeconds = cpuSeconds,
		avgCpuPercent = avgCpuPercent,
		processUptimeSeconds = processUptimeSeconds,
		residentSetSizeKb = status.VmRSS,
		memoryUsedKb = memoryUsedKb,
		memoryTotalKb = memoryTotalKb,
	}
end
