local builders = require("../../luau_packages/builders")

local config = require("../config")
local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local WELCOME_MESSAGES = {
	`Hey <@{0}>, welcome to the server! Glad you're here 🎉`,
	`<@{0}> just joined - everyone say hi! 👋`,
	`Welcome, <@{0}>! Hope you enjoy your stay 😄`,
	`A wild <@{0}> appeared! Welcome! ✨`,
	`<@{0}> has entered the chat. Welcome aboard! 🚀`,
	`Great to have you, <@{0}>! Welcome to the server 🙌`,
	`<@{0}> just landed. Welcome! 🛬`,
}

local Welcomer = {}

Welcomer.Priority = 0

local function getWelcomeMessage(userId: string): string
	local template = WELCOME_MESSAGES[math.random(1, #WELCOME_MESSAGES)]

	return string.format(template, userId)
end

function Welcomer:onReady()
	discordBot.onGuildMemberJoined:listen(function(data)
		if data.guildId ~= config.guildId then
			return
		end

		local userId = data.member.user and data.member.user.id or "unknown"

		local channelResult = discordBot:getChannelAsync(config.welcomeChannelId):await()

		if channelResult:isErr() then
			logger:warn(`Welcomer failed to fetch channel: {channelResult:unwrapErr()}`)

			return
		end

		local messageResult = channelResult
			:unwrapOk()
			:createMessageAsync(builders.message.message.new():setContent(getWelcomeMessage(userId)):build())
			:await()

		if messageResult:isErr() then
			logger:warn(`Welcomer failed to send welcome message for {userId}: {messageResult:unwrapErr()}`)
		else
			logger:info(`Sent welcome message for user {userId}`)
		end
	end)
end

export type Welcomer = typeof(Welcomer)

return Welcomer
