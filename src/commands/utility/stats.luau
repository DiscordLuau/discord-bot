local builders = require("../../../luau_packages/builders")

local logger = require("../../objects/logger")

local formatDuration = require("../../utilities/formatDuration")
local procStats = require("../../utilities/procStats")
local statsChart = require("../../utilities/statsChart")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("stats")
	:setDescription("Show bot process resource usage")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Utility",
	cooldown = { { seconds = 5, per = "user" } },

	execute = function(interaction)
		local deferResult = interaction:deferAsync():await()

		if deferResult:isErr() then
			logger:warn(`stats: deferAsync failed: {deferResult:unwrapErr()}`)

			return
		end

		local stats = procStats()
		local chartPng = statsChart()
		local avgCoresUsed = string.format("%.2f", stats.avgCpuPercent / 100)

		local memoryLine =
			`Memory: **{stats.residentSetSize}** RSS · **{stats.peakResidentSetSize}** peak · **{stats.virtualMemory}** virtual · **{stats.threads}** threads`
		local cpuLine =
			`CPU: **{string.format("%.2f", stats.cpuSeconds)}s** active · **{avgCoresUsed}** cores avg · Process uptime: **{formatDuration(
				stats.processUptimeSeconds
			)}**`

		local message = builders.message.message.new():setContent(memoryLine .. "\n" .. cpuLine)

		if chartPng then
			message:addAttachment(chartPng, "stats.png")
		end

		local result = interaction:editResponseAsync(message:build()):await()

		if result:isErr() then
			logger:warn(`stats: editResponseAsync failed: {result:unwrapErr()}`)
		end
	end,
}
