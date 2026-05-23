local builders = require("../../../luau_packages/builders")

local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")

local commands = require("../../singletons/commands")

local binder = require("../../utilities/binder")
local formatDuration = require("../../utilities/formatDuration")
local handleInteraction = require("../../utilities/handleInteraction")
local procStats = require("../../utilities/procStats")
local statsChart = require("../../utilities/statsChart")

local EPHEMERAL = 64

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("stats")
	:setDescription("Show bot process resource usage")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return function()
	local addToBinder, cleanup = binder()

	addToBinder(discordBot.onCommandInteraction:listen(function(interaction)
		if interaction.data.name ~= "stats" then
			return
		end

		handleInteraction(interaction, {}, function()
			local deferResult = interaction:deferAsync():await()

			if deferResult:isErr() then
				logger:warn(`stats: deferAsync failed: {deferResult:unwrapErr()}`)
				return
			end

			local stats = procStats()

			local chartPng = statsChart()

			local cores = string.format("%.2f", stats.avgCpuPercent / 100)

			local memoryLine = `Memory: **{stats.residentSetSize}** RSS · **{stats.peakResidentSetSize}** peak · **{stats.virtualMemory}** virtual · **{stats.threads}** threads`

			local cpuLine = `CPU: **{string.format("%.2f", stats.cpuSeconds)}s** active · **{cores}** cores avg · Process uptime: **{formatDuration(stats.processUptimeSeconds)}**`

			local message = builders.message.message
				.new()
				:setContent(memoryLine .. "\n" .. cpuLine)
				:setFlags(EPHEMERAL)

			if chartPng then
				message:addAttachment(chartPng, "stats.png")
			end

			local result = interaction:editResponseAsync(message:build()):await()

			if result:isErr() then
				logger:warn(`stats: editResponseAsync failed: {result:unwrapErr()}`)
			end
		end)
	end))

	commands:registerAsync(COMMAND_OBJECT)

	return cleanup
end
