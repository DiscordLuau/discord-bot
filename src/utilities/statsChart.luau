local logger = require("../objects/logger")

local database = require("../singletons/database")

local ENDPOINT = "https://quickchart.io/chart"

local function urlEncode(text: string): string
	return (text:gsub("[^%w%-%.%_%~]", function(char)
		return string.format("%%%02X", string.byte(char))
	end))
end


local function formatMegabytes(megabytes: number): string
	if megabytes >= 1024 then
		return string.format("%.1f GB", megabytes / 1024)
	end

	return string.format("%d MB", megabytes)
end

local function buildUrl(): string
	local rows = database.db
		:query("SELECT time, resident_set_size_in_kb FROM process_snapshots ORDER BY time DESC LIMIT 30")
		:all() :: any

	local labels = {}

	local memoryData = {}

	if rows and #rows > 0 then
		for index = #rows, 1, -1 do
			local row = rows[index]

			local date = os.date("!*t", row.time) :: any

			table.insert(labels, string.format("%02d:%02d", date.hour, date.min))
			table.insert(memoryData, math.floor(row.resident_set_size_in_kb / 1024 * 10) / 10)
		end
	end

	local currentRss = if #memoryData > 0 then memoryData[#memoryData] else 0

	local minRss = if #memoryData > 0 then math.min(table.unpack(memoryData)) else 0

	local maxRss = if #memoryData > 0 then math.max(table.unpack(memoryData)) else 0

	local minLine = {}

	local maxLine = {}

	for _ = 1, math.max(#memoryData, 1) do
		table.insert(minLine, minRss)
		table.insert(maxLine, maxRss)
	end

	local label = string.format(
		"RSS \xC2\xB7 %s \xC2\xB7 %s low \xC2\xB7 %s high",
		formatMegabytes(currentRss),
		formatMegabytes(minRss),
		formatMegabytes(maxRss)
	)

	local labelsJson = if #labels > 0 then '"' .. table.concat(labels, '","') .. '"' else ""

	local memoryJson = if #memoryData > 0 then table.concat(memoryData, ",") else "0"

	local minJson = table.concat(minLine, ",")

	local maxJson = table.concat(maxLine, ",")

	local chart = '{"type":"line","data":{"labels":['
		.. labelsJson
		.. '],"datasets":['
		.. '{"data":[' .. memoryJson .. '],"borderColor":"#89b4fa","backgroundColor":"rgba(137,180,250,0.2)","fill":true,"tension":0.4,"pointRadius":0,"borderWidth":1.5},'
		.. '{"data":[' .. minJson .. '],"borderColor":"#a6e3a1","borderDash":[4,4],"fill":false,"tension":0,"pointRadius":0,"borderWidth":1},'
		.. '{"data":[' .. maxJson .. '],"borderColor":"#f38ba8","borderDash":[4,4],"fill":false,"tension":0,"pointRadius":0,"borderWidth":1}'
		.. ']},'
		.. '"options":{"plugins":{"legend":{"display":false},'
		.. '"title":{"display":true,"text":"'
		.. label
		.. '","color":"#cdd6f4","font":{"size":11},"align":"center","padding":{"top":4,"bottom":0}}},'
		.. '"layout":{"padding":{"left":8,"right":8,"top":0,"bottom":4}},'
		.. '"scales":{"x":{"display":false},"y":{"display":false,"beginAtZero":true}}}}'

	return ENDPOINT .. "?c=" .. urlEncode(chart) .. "&w=600&h=150&bkg=" .. urlEncode("#1e1e2e") .. "&v=3"
end

return function(): string?
	local url = buildUrl()

	local ok, result = pcall(function()
		return zune.process.run("curl", { "-s", "--fail-with-body", url }) :: any
	end)

	if not ok then
		logger:warn(`statsChart: curl threw: {result}`)
		return nil
	end

	if result.code ~= 0 then
		logger:warn(`statsChart: curl exited {result.code}: {result.stderr}`)
		return nil
	end

	local data: string = result.stdout

	if #data < 4 or data:sub(1, 4) ~= "\x89PNG" then
		logger:warn(`statsChart: response is not a PNG ({#data} bytes)`)
		return nil
	end

	return data
end
