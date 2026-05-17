local builders = require("../../luau_packages/builders")

local config = require("../config")
local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local respondMessage = require("../utilities/respondMessage")
local truncate = require("../utilities/truncate")

local IS_SUBCOMMAND = "SubCommand"
local IS_SUBCOMMAND_GROUP = "SubCommandGroup"

local function stringifyOptions(options: { any }): string
	local parts = {}

	for _, option in options do
		if option.value == nil then
			continue
		end

		local value = tostring(option.value)

		if type(option.value) == "string" then
			value = `"{truncate(option.value, 50)}"`
		end

		table.insert(parts, `{option.name}:{value}`)
	end

	return table.concat(parts, " ")
end

local function buildFullCommand(commandName: string, options: { any }?): string
	if not options or #options == 0 then
		return commandName
	end

	local firstOption = options[1]

	if firstOption.type == IS_SUBCOMMAND_GROUP then
		local subcommand = firstOption.options and firstOption.options[1]
		local commandBase = `{commandName} {firstOption.name}`

		if subcommand and subcommand.type == IS_SUBCOMMAND then
			local optionString = stringifyOptions(subcommand.options or {})
			local commandPath = `{commandBase} {subcommand.name}`

			return if optionString ~= "" then `{commandPath} {optionString}` else commandPath
		end

		return commandBase
	end

	if firstOption.type == IS_SUBCOMMAND then
		local optionString = stringifyOptions(firstOption.options or {})
		local commandPath = `{commandName} {firstOption.name}`

		return if optionString ~= "" then `{commandPath} {optionString}` else commandPath
	end

	local optionString = stringifyOptions(options)

	return if optionString ~= "" then `{commandName} {optionString}` else commandName
end

return function(interaction: any)
	if config.systemsChannelId == "" then
		return
	end

	local userName = if interaction.member then interaction.member.user.username else interaction.user.username
	local userId = if interaction.member then interaction.member.user.id else interaction.user.id

	local fullCommand = buildFullCommand(interaction.data.name, interaction.data.options)
	local content = `\`{userName}\` ({userId}) used \`/{fullCommand}\` in <#{interaction.channelId}>`

	local channelResult = discordBot:getChannelAsync(config.systemsChannelId):await()

	if channelResult:isErr() then
		logger:warn(`logCommand failed to fetch systems channel: {channelResult:unwrapErr()}`)

		return
	end

	channelResult:unwrapOk():createMessageAsync(respondMessage({
		builders.message.components.container
			.new()
			:addComponent(builders.message.components.textDisplay.new():setContent(content):build())
			:build(),
	})):poll()
end
