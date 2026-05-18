local builders = require("../../../luau_packages/builders")

local discordBot = require("../../objects/discordBot")

local commands = require("../../singletons/commands")
local connectionStats = require("../../singletons/connectionStats")
local logSink = require("../../singletons/logSink")

local binder = require("../../utilities/binder")
local handleInteraction = require("../../utilities/handleInteraction")
local respondCommand = require("../../utilities/respondCommand")

local function formatDuration(seconds: number): string
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = seconds % 60

	local parts = {}

	if days > 0 then
		table.insert(parts, `{days}d`)
	end

	if hours > 0 then
		table.insert(parts, `{hours}h`)
	end

	if minutes > 0 then
		table.insert(parts, `{minutes}m`)
	end

	if remainingSeconds > 0 or #parts == 0 then
		table.insert(parts, `{remainingSeconds}s`)
	end

	return table.concat(parts, " ")
end

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("lifetime")
	:setDescription("Show bot connection stats")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:build()

return function()
	local addToBinder, cleanup = binder()

	addToBinder(discordBot.onCommandInteraction:listen(function(interaction)
		if interaction.data.name ~= "lifetime" then
			return
		end

		handleInteraction(interaction, {}, function()
			local now = os.time()
			local uptime = now - connectionStats.ConnectedAt
			local sessionUptime = now - connectionStats.LastConnectedAt
			local shards = connectionStats.ShardCount
			local reconnects = connectionStats.ReconnectCount
			local criticals = logSink.CriticalCount

			local reconnectLabel = reconnects == 1 and "Reconnection" or "Reconnections"
			local criticalLabel = criticals == 1 and "Critical Error" or "Critical Errors"
			local shardLabel = shards == 1 and "Shard" or "Shards"

			local response = `Uptime: **{formatDuration(uptime)}** · Session: **{formatDuration(sessionUptime)}** · **{reconnects}** {reconnectLabel} · **{criticals}** {criticalLabel} · **{shards}** {shardLabel}`

			interaction:messageAsync(respondCommand(response)):poll()
		end)
	end))

	commands:registerAsync(COMMAND_OBJECT)

	return cleanup
end
