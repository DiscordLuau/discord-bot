local emitter = require("../../luau_packages/emitter")

local config = require("../config")
local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local VoiceStates = {}

VoiceStates.Priority = 0
VoiceStates.ChannelByUser = {} :: { [string]: string }
VoiceStates.BotUserIds = {} :: { [string]: boolean }
VoiceStates.onChanged = emitter.new() :: emitter.Emitter<string, string?, string?>

local function setChannel(userId: string, channelId: string?)
	local oldChannelId = VoiceStates.ChannelByUser[userId]

	if oldChannelId == channelId then
		logger:debug(`VoiceStates {userId} stays in {channelId or "no channel"}`)

		return
	end

	VoiceStates.ChannelByUser[userId] = channelId
	VoiceStates.onChanged:invoke(userId, oldChannelId, channelId)
end

local function seed()
	local guildData: any = discordBot.state.cache.guilds:get(config.guildId)
	local seeded: { [string]: string } = {}
	local departed: { string } = {}
	local seededCount = 0

	if not guildData then
		logger:debug(`VoiceStates has no cached guild {config.guildId} yet; it seeds on GUILD_CREATE`)

		return
	end

	if not guildData.voice_states then
		logger:warn(`VoiceStates found no voice states in the cached guild {config.guildId}; keeping the current map`)

		return
	end

	for _, member in guildData.members or {} do
		if member.user and member.user.bot then
			VoiceStates.BotUserIds[member.user.id] = true
		end
	end

	for _, voiceState in guildData.voice_states do
		if voiceState.channel_id then
			seeded[voiceState.user_id] = voiceState.channel_id
			seededCount += 1
		end
	end

	for userId in VoiceStates.ChannelByUser do
		if not seeded[userId] then
			table.insert(departed, userId)
		end
	end

	for _, userId in departed do
		setChannel(userId, nil)
	end

	for userId, channelId in seeded do
		setChannel(userId, channelId)
	end

	logger:info(`VoiceStates seeded {seededCount} voice state(s) for guild {config.guildId}`)
end

function VoiceStates:getChannel(userId: string): string?
	return self.ChannelByUser[userId]
end

function VoiceStates:countListeners(channelId: string): number
	local botUserId = discordBot.state.userId
	local count = 0

	for userId, userChannelId in self.ChannelByUser do
		if userChannelId == channelId and userId ~= botUserId and not self.BotUserIds[userId] then
			count += 1
		end
	end

	return count
end

function VoiceStates:onReady()
	seed()

	discordBot.onGuildCreate:listen(function(guild)
		if guild.id ~= config.guildId then
			logger:debug(`VoiceStates ignores GUILD_CREATE for guild {guild.id}`)

			return
		end

		if guild.isUnavailable then
			logger:debug(`VoiceStates skipped a reseed for an unavailable guild {guild.id}`)

			return
		end

		seed()
	end)

	discordBot.onVoiceStateUpdate:listen(function(voiceState)
		if voiceState.guildId ~= config.guildId then
			logger:debug(`VoiceStates ignores a voice state in guild {voiceState.guildId or "none"}`)

			return
		end

		local user = if voiceState.member then voiceState.member.user else nil

		if user and user.bot then
			self.BotUserIds[voiceState.userId] = true
		end

		setChannel(voiceState.userId, voiceState.channelId)
	end)
end

export type VoiceStates = typeof(VoiceStates) & {
	Priority: number,
	ChannelByUser: { [string]: string },
	BotUserIds: { [string]: boolean },
	onChanged: emitter.Emitter<string, string?, string?>,
}

return VoiceStates
