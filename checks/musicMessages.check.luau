local musicMessages = require("../src/utilities/musicMessages")
local musicQueue = require("../src/utilities/musicQueue")

local REFUSAL =
	"audio source failed: yt-dlp exited with code 1: ERROR: [youtube] abc: Sign in to confirm you're not a bot. Use --cookies-from-browser or --cookies for the authentication."
local ZERO_WIDTH_SPACE = utf8.char(0x200B)
local UNAVAILABLE = "audio source failed: yt-dlp exited with code 1: ERROR: [youtube] abc: Video unavailable"

local function track(id: string, title: string, durationSeconds: number?): musicQueue.Track
	return { id = id, title = title, durationSeconds = durationSeconds, requesterId = "42" }
end

local function checkMessages()
	local song = track("a", "Song", 225)
	local live = track("b", "Live", nil)
	local posted = musicMessages.nowPlaying(song)
	local notice = musicMessages.notice("Left voice")

	assert(
		musicMessages.escape("*NEW* my_song [x] @everyone") == `\\*NEW\\* my\\_song \\[x\\] @{ZERO_WIDTH_SPACE}everyone`,
		"escape stops markdown and pings"
	)
	assert(musicMessages.escape("a\\b~c`d|e>f") == "a\\\\b\\~c\\`d\\|e\\>f", "escape stops every markdown character")
	assert(musicMessages.trackLine(song) == "**Song** (3m 45s)", "a track line is the bold title and its length")
	assert(musicMessages.trackLine(live) == "**Live** (unknown length)", "a missing duration reads unknown length")
	assert(
		musicMessages.queuedTrack(song, nil) == "Playing **Song** (3m 45s)",
		"a song that starts at once says Playing"
	)
	assert(
		musicMessages.queuedTrack(song, 3) == "Queued **Song** (3m 45s), position 3",
		"a queued song gives its position"
	)
	assert(
		musicMessages.queuedPlaylist(52, "Mix_1") == "Queued 52 songs from **Mix\\_1**",
		"a playlist names its title"
	)
	assert(musicMessages.queuedPlaylist(1, nil) == "Queued 1 song", "one song is singular")
	assert(musicMessages.queuedPlaylist(2, nil) == "Queued 2 songs", "a playlist without a title still pluralises")
	assert(
		posted.content == "Now playing **Song** (3m 45s), requested by <@42>",
		`now playing names the requester, got {posted.content}`
	)
	assert(#posted.allowed_mentions.parse == 0 and notice.content == "Left voice", "posts ping nobody")
	assert(
		musicMessages.nowPlayingStatus(song, 62, false) == "Now playing **Song** (3m 45s), 1m 2s in",
		"the status says how far the song is"
	)
	assert(
		musicMessages.nowPlayingStatus(song, 62, true) == "Paused **Song** (3m 45s) at 1m 2s",
		"a paused song says so"
	)
	assert(
		musicMessages.isCookieRefusal(REFUSAL) and not musicMessages.isCookieRefusal(UNAVAILABLE),
		"only the sign-in error is a cookie refusal"
	)
	assert(
		musicMessages.trackFailed(song, REFUSAL)
			== "YouTube refused the download, the bot's YouTube cookies need refreshing",
		"a cookie refusal asks for fresh cookies"
	)
	assert(
		musicMessages.failureReason(UNAVAILABLE) == "[youtube] abc: Video unavailable",
		"the reason drops the wrappers"
	)
	assert(
		musicMessages.failureReason("audio source failed: could not start yt-dlp: FileNotFound")
			== "could not start yt-dlp: FileNotFound",
		"a start failure keeps its own words"
	)
	assert(
		musicMessages.trackFailed(song, UNAVAILABLE)
			== "Couldn't play **Song** (3m 45s): \\[youtube\\] abc: Video unavailable",
		"other failures name the song and the reason"
	)
	assert(musicMessages.leftIdle(120) == "Left voice after 2m with nothing to play", "the idle notice")
	assert(musicMessages.leftEmpty(120) == "Left voice after 2m with nobody listening", "the empty channel notice")
	assert(
		musicMessages.disconnected("removed from the voice channel")
			== "Disconnected from voice: removed from the voice channel",
		"the disconnect notice"
	)
end

local function checkQueuePage()
	local queue = {}

	for index = 1, 23 do
		table.insert(queue, track(`t{index}`, `Song {index}`, if index == 5 then nil else 60))
	end

	local firstPage = musicMessages.queuePage(musicQueue.page(queue, track("a", "Song", 225), 1, 10))
	local middlePage = musicMessages.queuePage(musicQueue.page(queue, nil, 2, 10))
	local lastPage = musicMessages.queuePage(musicQueue.page(queue, nil, 3, 10))
	local emptyPage = musicMessages.queuePage(musicQueue.page({}, nil, 1, 10))
	local container = firstPage.components[1]
	local text = container.components[1].content
	local buttons = container.components[2].components
	local middleButtons = middlePage.components[1].components[2].components
	local lastText = lastPage.components[1].components[1].content
	local lastButtons = lastPage.components[1].components[2].components
	local emptyText = emptyPage.components[1].components[1].content
	local closed = musicMessages.queueClosed()

	assert(firstPage.flags == 32768, "the queue page is a components v2 message")
	assert(
		string.find(text, "Now playing: **Song** (3m 45s)", 1, true),
		`the page starts with the current song, got {text}`
	)
	assert(
		string.find(text, "Up next: 23 songs, 22m plus 1 of unknown length", 1, true),
		`the page sums the queue, got {text}`
	)
	assert(
		string.find(text, "1. **Song 1** (1m)", 1, true) and string.find(text, "10. **Song 10** (1m)", 1, true),
		"page 1 lists positions 1 to 10"
	)
	assert(string.find(text, "5. **Song 5** (unknown length)", 1, true), "the page marks an unknown-length song")
	assert(not string.find(text, "11. ", 1, true), "page 1 stops at position 10")
	assert(string.find(text, "-# Page 1 of 3", 1, true), "the page says where it is")
	assert(buttons[1].custom_id == "music:queue:0" and buttons[1].disabled == true, "Previous is off on page 1")
	assert(buttons[2].custom_id == "music:queue:2" and buttons[2].disabled == false, "Next goes to page 2")
	assert(
		middleButtons[1].custom_id == "music:queue:1" and middleButtons[1].disabled == false,
		"Previous goes back from page 2"
	)
	assert(
		middleButtons[2].custom_id == "music:queue:3" and middleButtons[2].disabled == false,
		"Next goes on from page 2"
	)
	assert(
		lastButtons[1].custom_id == "music:queue:2"
			and lastButtons[1].disabled == false
			and lastButtons[2].disabled == true,
		"Previous works and Next is off on the last page"
	)
	assert(not string.find(lastText, "Now playing:", 1, true), "a page without a current song has no Now playing line")
	assert(string.find(emptyText, "Nothing is queued", 1, true), "an empty queue says nothing is queued")
	assert(closed.components[1].components[1].content == "Nothing is playing", "a closed queue says nothing is playing")
	assert(musicMessages.queueButtonPage("music:queue:2") == 2, "a queue button names its page")
	assert(
		not musicMessages.queueButtonPage("close_thread:1") and not musicMessages.queueButtonPage(nil),
		"other buttons are not queue buttons"
	)
end

checkMessages()
checkQueuePage()
print("musicMessages checks passed")
