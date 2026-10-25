local builders = require("../../../luau_packages/builders")

local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")
local music = require("../../singletons/music")
local voiceStates = require("../../singletons/voiceStates")

local musicMessages = require("../../utilities/musicMessages")
local musicQueue = require("../../utilities/musicQueue")
local respondCommand = require("../../utilities/respondCommand")
local truncate = require("../../utilities/truncate")
local youtube = require("../../utilities/youtube")

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("play")
	:setDescription("Play a YouTube video or playlist in your voice channel")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:addOption(
		builders.interaction.option
			.new()
			:setType("String")
			:setName("link")
			:setDescription("A YouTube video or playlist link")
			:setRequired(true)
			:build()
	)
	:build()

local function canTakeMessages(channelId: string): boolean
	local channelResult = discordBot:getChannelAsync(channelId):await()
	local channel = if channelResult:isOk() then channelResult:unwrapOk() else nil

	if channelResult:isErr() then
		logger:warn(`/play couldn't fetch channel {channelId}: {channelResult:unwrapErr()}`)
	end

	return if channel and channel.createMessageAsync then true else false
end

local function refuse(interaction: any, reply: string, reason: string)
	logger:debug(`/play refused: {reason}`)
	interaction:messageAsync(respondCommand(reply, true)):poll()
end

local function editReply(interaction: any, reply: string)
	local editResult = interaction:editResponseAsync(respondCommand(reply)):await()

	if editResult:isErr() then
		logger:warn(`/play: editResponseAsync failed: {editResult:unwrapErr()}`)
	end
end

return {
	command = COMMAND_OBJECT,
	category = "Music",
	cooldown = { { seconds = 3, per = "user" } },

	execute = function(interaction)
		local member = interaction.member

		if not member then
			logger:debug(`/play: no guild member; this command works only in the server`)
			interaction:messageAsync(respondCommand("This command works only in the server", true)):poll()

			return
		end

		local userId = member.user.id
		local link = interaction:getString("link") or ""
		local parsedLink = youtube.parseLink(link)
		local voiceChannelId = voiceStates:getChannel(userId)
		local session = music.Session

		if music.CookiesMissing then
			logger:warn(`/play refused: this bot has no YouTube cookies file`)
			interaction
				:messageAsync(respondCommand("Music is not set up on this bot (no YouTube cookies)", true))
				:poll()

			return
		end

		if not parsedLink then
			refuse(interaction, "That isn't a YouTube video or playlist link", `not a YouTube link: {link}`)

			return
		end

		if not voiceChannelId then
			refuse(interaction, "Join a voice channel first", `{userId} is not in voice`)

			return
		end

		if session and session.channelId ~= voiceChannelId then
			refuse(
				interaction,
				`I'm playing in <#{session.channelId}>, join it to add songs`,
				`{userId} is in {voiceChannelId}, the bot in {session.channelId}`
			)

			return
		end

		if not canTakeMessages(interaction.channelId) then
			refuse(
				interaction,
				"Run /play from a text channel, that's where I post what's playing",
				`channel {interaction.channelId} can't take messages`
			)

			return
		end

		local deferResult = interaction:deferAsync():await()

		if deferResult:isErr() then
			logger:warn(`/play: deferAsync failed: {deferResult:unwrapErr()}`)

			return
		end

		local listed, entriesOrFailure, playlistTitle = youtube.listAsync(parsedLink)

		if not listed then
			logger:debug(`/play: {parsedLink.url} could not be listed`)
			editReply(
				interaction,
				`Couldn't read that link: {musicMessages.escape(truncate(entriesOrFailure :: string, 1500))}`
			)

			return
		end

		local tracks = musicQueue.toTracks(entriesOrFailure :: { youtube.Entry }, userId)

		if #tracks == 0 then
			logger:debug(`/play: {parsedLink.url} listed no songs`)
			editReply(interaction, "That link has no songs I can play")

			return
		end

		local queued, failure = music:enqueueAsync(voiceChannelId, interaction.channelId, tracks)
		local queuedSession = music.Session
		local position = if queuedSession then table.find(queuedSession.queue, tracks[1]) else nil
		local reply = if not queued
			then failure or "Couldn't queue that"
			elseif parsedLink.kind == "playlist" then musicMessages.queuedPlaylist(#tracks, playlistTitle)
			else musicMessages.queuedTrack(tracks[1], position)

		editReply(interaction, reply)
	end,
}
