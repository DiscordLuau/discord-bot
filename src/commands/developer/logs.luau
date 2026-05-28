local builders = require("../../../luau_packages/builders")

local logger = require("../../objects/logger")
local logSink = require("../../singletons/logSink")

local logBlock = require("../../utilities/logBlock")
local permissionGuard = require("../../utilities/permissionGuard")
local respondCommand = require("../../utilities/respondCommand")

local function parseAfter(input: string): number?
	local hours: number
	local minutes: number
	local seconds: number

	local withSeconds = input:match("^%d+:%d+:%d+%.?%d*$")

	if withSeconds then
		local rawHours, rawMinutes, rawSeconds = input:match("^(%d+):(%d+):(%d+)")

		hours = tonumber(rawHours) :: number
		minutes = tonumber(rawMinutes) :: number
		seconds = math.floor(tonumber(rawSeconds) or 0)
	else
		local rawHours, rawMinutes = input:match("^(%d+):(%d+)$")

		if not rawHours or not rawMinutes then
			return nil
		end

		hours = tonumber(rawHours) :: number
		minutes = tonumber(rawMinutes) :: number
		seconds = 0
	end

	local now = os.time()
	local utcNow = os.date("!*t", now) :: any
	local midnight = now - (utcNow.hour * 3600 + utcNow.min * 60 + utcNow.sec)
	local cutoff = midnight + hours * 3600 + minutes * 60 + seconds

	if cutoff > now then
		cutoff -= 86400
	end

	return cutoff
end

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("logs")
	:setDescription("Query captured bot logs")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:addContext("BotDm")
	:addContext("PrivateChannel")
	:setDefaultMemberPermissions(8)
	:addOption(
		builders.interaction.option
			.new()
			:setType("String")
			:setName("level")
			:setDescription("Minimum log level to show")
			:addChoice(builders.interaction.choice.new():setName("Debug"):setValue("Debug"):build())
			:addChoice(builders.interaction.choice.new():setName("Info"):setValue("Info"):build())
			:addChoice(builders.interaction.choice.new():setName("Notice"):setValue("Notice"):build())
			:addChoice(builders.interaction.choice.new():setName("Warn"):setValue("Warn"):build())
			:addChoice(builders.interaction.choice.new():setName("Error"):setValue("Error"):build())
			:addChoice(builders.interaction.choice.new():setName("Critical"):setValue("Critical"):build())
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("String")
			:setName("after")
			:setDescription("Show logs after this UTC time (e.g. 22:07, 22:07:15, 22:07:15.877)")
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("Integer")
			:setName("count")
			:setDescription("Number of log lines to return (default 15)")
			:setMinValue(1)
			:setMaxValue(50)
			:build()
	)
	:build()

return {
	command = COMMAND_OBJECT,
	category = "Developer",
	cooldown = { { seconds = 10, per = "user" } },
	guards = { permissionGuard({ "developer" }) },

	execute = function(interaction)
		local options = interaction.data.options or {}
		local level: string? = nil
		local after: number? = nil
		local afterRaw: string? = nil
		local count: number? = nil

		interaction:deferAsync():poll()

		for _, option in options do
			if option.name == "level" then
				level = option.value
			elseif option.name == "after" then
				afterRaw = option.value
				after = parseAfter(option.value)

				if not after then
					logger:warn(`Received /logs with invalid time format: '{option.value}'`)

					interaction
						:messageAsync(
							respondCommand(
								`Invalid time format \`{option.value}\`. Use \`HH:MM\`, \`HH:MM:SS\`, or \`HH:MM:SS.mmm\`.`,
								true
							)
						)
						:poll()

					return
				end
			elseif option.name == "count" then
				count = option.value
			end
		end

		local messages = logSink:query({ level = level, after = after, count = count })

		if #messages == 0 then
			interaction:messageAsync(respondCommand("No logs matched the given filters.", true)):poll()

			return
		end

		local block = logBlock({ level = level, after = after, count = count }, 1900)
		local header = `Showing **{#messages}** line{#messages ~= 1 and "s" or ""}`

		if level then
			header ..= ` · Level ≥ **{level}**`
		end

		if afterRaw then
			header ..= ` · After **{afterRaw}**`
		end

		interaction:messageAsync(respondCommand(header .. "\n" .. block)):poll()
	end,
}
