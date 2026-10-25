local audio = require("../../luau_packages/audio")
local emitter = require("../../luau_packages/emitter")

local config = require("../config")
local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")
local voiceStates = require("../singletons/voiceStates")

local musicMessages = require("../utilities/musicMessages")
local musicQueue = require("../utilities/musicQueue")
local truncate = require("../utilities/truncate")
local youtube = require("../utilities/youtube")

local joining = false
local joinFinished = emitter.new() :: emitter.Emitter<string?>

local Music = {}

Music.Priority = 0
Music.Session = nil :: Session?
Music.CookiesMissing = false

local function post(session: Session, message: any)
	zune.task.spawn(function()
		local channelResult = discordBot:getChannelAsync(session.textChannelId):await()

		if channelResult:isErr() then
			logger:warn(`Music couldn't fetch text channel {session.textChannelId}: {channelResult:unwrapErr()}`)

			return
		end

		local sendResult = channelResult:unwrapOk():createMessageAsync(message):await()

		if sendResult:isErr() then
			logger:warn(`Music couldn't post in {session.textChannelId}: {sendResult:unwrapErr()}`)
		end
	end)
end

local function cancelIdleTimer(session: Session)
	local idleThread = session.idleThread

	if not idleThread then
		logger:debug(`Music has no idle timer to cancel in {session.channelId}`)

		return
	end

	session.idleThread = nil
	zune.task.cancel(idleThread)
	logger:debug(`Music cancelled the idle timer in {session.channelId}`)
end

local function endSession(session: Session, notice: string?)
	if Music.Session ~= session then
		logger:debug(`Music session in {session.channelId} has already ended`)

		return
	end

	Music.Session = nil
	session.queue = {}
	cancelIdleTimer(session)
	session.player:stop()

	if notice then
		post(session, musicMessages.notice(notice))
	end

	local leaveResult = session.connection:leaveAsync():await()

	if leaveResult:isErr() then
		logger:warn(`Music couldn't leave voice channel {session.channelId}: {leaveResult:unwrapErr()}`)
	end

	logger:info(`Music session in {session.channelId} ended`)
end

local function startIdleTimer(session: Session, notice: string)
	if session.idleThread then
		logger:debug(`Music idle timer already runs in {session.channelId}`)

		return
	end

	logger:info(`Music will leave {session.channelId} in {config.music.idleLeaveSeconds}s unless something plays`)
	session.idleThread = zune.task.delay(config.music.idleLeaveSeconds, function()
		session.idleThread = nil
		endSession(session, notice)
	end)
end

local function updateIdleTimer(session: Session)
	local listenerCount = voiceStates:countListeners(session.channelId)

	if listenerCount == 0 then
		startIdleTimer(session, musicMessages.leftEmpty(config.music.idleLeaveSeconds))
	elseif session.current then
		cancelIdleTimer(session)
	else
		logger:debug(`Music stays idle in {session.channelId} with {listenerCount} listener(s)`)
	end
end

local function playTrack(session: Session, track: Track)
	local source = audio.fromProcess(config.music.ytDlpPath, youtube.streamArguments(track.id))

	session.current = track
	musicQueue.startTiming(session, os.time())
	post(session, musicMessages.nowPlaying(track))
	logger:info(`Music playing {track.id} in {session.channelId}`)

	local playResult = session.player:playAsync(source):await()

	if playResult:isOk() then
		logger:info(`Music song {track.id} {playResult:unwrapOk()}`)

		return
	end

	local failure = tostring(playResult:unwrapErr())

	if Music.Session ~= session then
		logger:debug(`Music song {track.id} ended with its session: {failure}`)

		return
	end

	if musicMessages.isCookieRefusal(failure) then
		logger:warn(`Music was refused {track.id} by YouTube; the bot's YouTube cookies need refreshing ({failure})`)
	else
		logger:info(`Music couldn't play {track.id}: {failure}`)
	end

	post(session, musicMessages.notice(musicMessages.trackFailed(track, truncate(failure, 1500))))
end

local function playQueue(session: Session)
	while Music.Session == session do
		local track = table.remove(session.queue, 1)

		if not track then
			session.current = nil
			logger:info(`Music queue in {session.channelId} is empty`)
			startIdleTimer(session, musicMessages.leftIdle(config.music.idleLeaveSeconds))

			return
		end

		playTrack(session, track)
	end

	logger:debug(`Music stopped playing in {session.channelId}: the session ended`)
end

local function joinVoice(channelId: string): (any?, string?)
	local channelResult = discordBot:getVoiceChannelAsync(channelId):await()

	if channelResult:isErr() then
		local failure = tostring(channelResult:unwrapErr())

		logger:warn(`Music couldn't fetch voice channel {channelId}: {failure}`)

		return nil, failure
	end

	local joinResult = channelResult:unwrapOk():joinAsync():await()

	if joinResult:isErr() then
		local failure = tostring(joinResult:unwrapErr())

		logger:warn(`Music couldn't join voice channel {channelId}: {failure}`)

		return nil, failure
	end

	return joinResult:unwrapOk()
end

local function openSession(channelId: string, textChannelId: string, connection: any): Session
	local session: Session = {
		channelId = channelId,
		textChannelId = textChannelId,
		connection = connection,
		player = audio.player.new(connection),
		queue = {},
		pausedSeconds = 0,
	}

	Music.Session = session
	connection.onClosed:listen(function()
		endSession(session, musicMessages.disconnected(connection.closeDetail))
	end)
	logger:info(`Music joined voice channel {channelId}; posting in {textChannelId}`)

	return session
end

local function queueTracks(session: Session, tracks: { Track })
	for _, track in tracks do
		table.insert(session.queue, track)
	end

	logger:info(`Music queued {#tracks} song(s) in {session.channelId}`)

	if not session.current then
		zune.task.spawn(playQueue, session)
	end

	updateIdleTimer(session)
end

local function onVoiceChanged(userId: string, oldChannelId: string?, newChannelId: string?)
	local session = Music.Session
	local isBot = userId == discordBot.state.userId

	if not session then
		logger:debug(`Music ignores a voice change for {userId}: nothing is playing`)
	elseif isBot and not newChannelId then
		endSession(session, musicMessages.disconnected("removed from the voice channel"))
	elseif isBot and newChannelId ~= session.channelId then
		session.channelId = newChannelId :: string
		logger:info(`Music followed the bot to voice channel {newChannelId}`)
		updateIdleTimer(session)
	elseif oldChannelId == session.channelId or newChannelId == session.channelId then
		updateIdleTimer(session)
	else
		logger:debug(`Music ignores a voice change for {userId} outside {session.channelId}`)
	end
end

local function onQueueButton(interaction: any)
	local customId = if interaction.data then interaction.data.customId else nil
	local page = musicMessages.queueButtonPage(customId)

	if not page then
		logger:debug(`Music ignores component {customId or "without an id"}`)

		return
	end

	local queuePage = Music:queuePage(page)
	local message = if queuePage then musicMessages.queuePage(queuePage) else musicMessages.queueClosed()
	local updateResult = interaction:updateAsync(message):await()

	if updateResult:isErr() then
		logger:warn(`Music couldn't turn the /queue page: {updateResult:unwrapErr()}`)
	end
end

function Music:enqueueAsync(channelId: string, textChannelId: string, tracks: { Track }): (boolean, string?)
	if joining then
		logger:info(`Music holds {#tracks} song(s) until the voice join in progress ends`)

		local joinFailure = joinFinished:wait()

		if joinFailure then
			logger:debug(`Music queued nothing: the join it waited on failed`)

			return false, `Couldn't join your voice channel: {joinFailure}`
		end
	end

	local session = self.Session

	if session and session.channelId ~= channelId then
		logger:debug(`Music turned away {#tracks} song(s) for {channelId}: it plays in {session.channelId}`)

		return false, `I'm playing in <#{session.channelId}>, join it to add songs`
	end

	if session then
		queueTracks(session, tracks)

		return true
	end

	joining = true
	logger:info(`Music joining voice channel {channelId}`)

	local connection, failure = joinVoice(channelId)

	joining = false

	if not connection then
		logger:debug(`Music queued nothing: the join failed`)
		joinFinished:invoke(failure)

		return false, `Couldn't join your voice channel: {failure}`
	end

	queueTracks(openSession(channelId, textChannelId, connection), tracks)
	joinFinished:invoke(nil)

	return true
end

function Music:skip(): boolean
	local session = self.Session

	if not session or not session.player.playing then
		logger:debug(`Music:skip with nothing playing`)

		return false
	end

	logger:info(`Music skipping a song in {session.channelId}`)
	session.player:stop()

	return true
end

function Music:stop()
	local session = self.Session

	if not session then
		logger:debug(`Music:stop with no session`)

		return
	end

	endSession(session, nil)
end

function Music:pause(): boolean
	local session = self.Session

	if not session then
		logger:debug(`Music:pause with no session`)

		return false
	end

	local paused = session.player:pause()

	if not paused then
		logger:debug(`Music didn't pause in {session.channelId}: nothing playing, already paused or ending`)

		return false
	end

	musicQueue.pauseTiming(session, os.time())
	logger:info(`Music paused in {session.channelId}`)

	return paused
end

function Music:resume(): boolean
	local session = self.Session

	if not session then
		logger:debug(`Music:resume with no session`)

		return false
	end

	local resumed = session.player:resume()

	if not resumed then
		logger:debug(`Music didn't resume in {session.channelId}: nothing playing, not paused or stopping`)

		return false
	end

	musicQueue.resumeTiming(session, os.time())
	logger:info(`Music resumed in {session.channelId}`)

	return resumed
end

function Music:remove(position: number): Track?
	local session = self.Session
	local removed = if session then musicQueue.remove(session.queue, position) else nil

	if removed then
		logger:info(`Music removed {removed.id} from position {position}`)
	else
		logger:debug(`Music has no song at position {position} to remove`)
	end

	return removed
end

function Music:shuffle(): number
	local session = self.Session

	if not session then
		logger:debug(`Music:shuffle with no session`)

		return 0
	end

	local count = musicQueue.shuffle(session.queue, math.random)

	logger:info(`Music shuffled {count} song(s) in {session.channelId}`)

	return count
end

function Music:nowPlaying(): (Track?, number)
	local session = self.Session
	local current = if session then session.current else nil

	if not session or not current then
		logger:debug(`Music:nowPlaying with nothing playing`)

		return nil, 0
	end

	return current, musicQueue.elapsedSeconds(session, os.time())
end

function Music:queuePage(page: number): musicQueue.QueuePage?
	local session = self.Session

	if not session then
		logger:debug(`Music has no queue to show (page {page})`)

		return
	end

	return musicQueue.page(session.queue, session.current, page, config.music.queuePageSize)
end

function Music:onReady()
	local cookiesPath = config.music.cookiesPath

	if not cookiesPath then
		logger:info(`Music runs yt-dlp without YouTube cookies: YOUTUBE_COOKIES_PATH is not set`)
	elseif zune.fs.stat(cookiesPath).kind ~= "file" then
		self.CookiesMissing = true
		logger:warn(`Music found no YouTube cookies file at {cookiesPath}; /play is turned off`)
	else
		logger:info(`Music reads YouTube cookies from {cookiesPath}`)
	end

	voiceStates.onChanged:listen(function(userId: string, oldChannelId: string?, newChannelId: string?)
		onVoiceChanged(userId, oldChannelId, newChannelId)
	end)

	discordBot.onComponentInteraction:listen(function(interaction)
		onQueueButton(interaction)
	end)
end

export type Track = musicQueue.Track

export type Session = {
	channelId: string,
	textChannelId: string,
	connection: any,
	player: audio.Player,
	queue: { Track },
	current: Track?,
	startedAt: number?,
	pausedAt: number?,
	pausedSeconds: number,
	idleThread: thread?,
}

export type Music = typeof(Music) & {
	Priority: number,
	Session: Session?,
	CookiesMissing: boolean,
}

return Music
