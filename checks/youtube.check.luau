local config = require("../src/config")
local youtube = require("../src/utilities/youtube")

local VIDEO_ID = "dQw4w9WgXcQ"
local VIDEO_URL = `https://www.youtube.com/watch?v={VIDEO_ID}`
local PLAYLIST_ID = "PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI"
local PLAYLIST_URL = `https://www.youtube.com/playlist?list={PLAYLIST_ID}`
local COOKIES_PATH = "/tmp/youtube-cookies.txt"

local originalCookiesPath = config.music.cookiesPath
local originalYtDlpPath = config.music.ytDlpPath

local function expectLink(link: string, kind: string, url: string)
	local parsed = youtube.parseLink(link)

	assert(parsed, `{link} parses`)
	assert(parsed.kind == kind, `{link} is a {kind}, got {parsed.kind}`)
	assert(parsed.url == url, `{link} becomes {url}, got {parsed.url}`)
end

local function listWith(ytDlpPath: string): (boolean, any)
	config.music.ytDlpPath = ytDlpPath

	return youtube.listAsync({ kind = "video", url = VIDEO_URL })
end

local function checkLinks()
	local videoLinks = {
		VIDEO_URL,
		`https://youtube.com/watch?v={VIDEO_ID}&t=42s`,
		`http://m.youtube.com/watch?feature=share&v={VIDEO_ID}`,
		`youtube.com/watch?v={VIDEO_ID}`,
		`https://youtu.be/{VIDEO_ID}?si=abc123`,
		`https://www.youtube.com/shorts/{VIDEO_ID}`,
		`https://music.youtube.com/watch?v={VIDEO_ID}&list=RDAMVM{VIDEO_ID}`,
		`https://www.youtube.com/watch?v={VIDEO_ID}&list={PLAYLIST_ID}&index=3`,
		`  https://youtu.be/{VIDEO_ID}  `,
	}
	local playlistLinks = { PLAYLIST_URL, `https://youtube.com/playlist?list={PLAYLIST_ID}&si=xyz` }
	local rejectedLinks = {
		"",
		"not a link",
		"https://vimeo.com/123456",
		`https://www.youtube.com.evil.example/watch?v={VIDEO_ID}`,
		`https://notyoutube.com/watch?v={VIDEO_ID}`,
		"https://www.youtube.com/watch?v=short",
		"https://www.youtube.com/watch",
		"https://www.youtube.com/@somechannel",
		"https://www.youtube.com/playlist?list=",
		`https://music.youtube.com/playlist?list={PLAYLIST_ID}`,
		`https://youtu.be/{VIDEO_ID}x`,
	}

	for _, link in videoLinks do
		expectLink(link, "video", VIDEO_URL)
	end

	for _, link in playlistLinks do
		expectLink(link, "playlist", PLAYLIST_URL)
	end

	for _, link in rejectedLinks do
		assert(not youtube.parseLink(link), `{link} is not a YouTube video or playlist link`)
	end
end

local function checkListing()
	local listing = table.concat({
		`{VIDEO_ID}\t213\tNever Gonna Give You Up`,
		"abcdefghijk\tNA\tA live stream",
		"zyxwvutsrqp\t95.0\tTitle\twith\ttabs",
		"",
		"#playlist\tMy Mix",
		"a line yt-dlp should never print",
	}, "\n")
	local entries, playlistTitle = youtube.parseListing(listing)
	local single, noTitle = youtube.parseListing(`{VIDEO_ID}\t213\tSong\n`)

	assert(#entries == 3, `three entries are read, got {#entries}`)
	assert(entries[1].id == VIDEO_ID and entries[1].durationSeconds == 213, "an entry has its id and duration")
	assert(entries[1].title == "Never Gonna Give You Up", "an entry has its title")
	assert(not entries[2].durationSeconds, "an NA duration is nil")
	assert(entries[3].title == "Title\twith\ttabs" and entries[3].durationSeconds == 95, "a title keeps its tabs")
	assert(playlistTitle == "My Mix", "the playlist line gives the playlist title")
	assert(#single == 1 and not noTitle, "a single video has no playlist title")
	assert(
		youtube.errorLine("WARNING: slow\nERROR: [youtube] abc: Video unavailable\n\n")
			== "[youtube] abc: Video unavailable",
		"the error line is the last line without ERROR:"
	)
	assert(not youtube.errorLine("  \n"), "blank output has no error line")
end

local function checkArguments()
	config.music.cookiesPath = nil
	assert(
		table.concat(youtube.streamArguments(VIDEO_ID), " ") == `-f 251/bestaudio --no-playlist -o - {VIDEO_URL}`,
		"a stream without a cookies path passes no --cookies"
	)
	assert(
		not table.find(youtube.listArguments({ kind = "playlist", url = PLAYLIST_URL }), "--cookies"),
		"a listing without a cookies path passes no --cookies"
	)

	config.music.cookiesPath = COOKIES_PATH
	assert(
		table.concat(youtube.streamArguments(VIDEO_ID), " ")
			== `-f 251/bestaudio --no-playlist --cookies {COOKIES_PATH} -o - {VIDEO_URL}`,
		"a stream passes the cookies path"
	)
	assert(
		table.concat(youtube.listArguments({ kind = "playlist", url = PLAYLIST_URL }), " ")
			== `--flat-playlist --simulate --no-warnings --ignore-no-formats-error --print %(id)s\t%(duration)s\t%(title)s --print playlist:#playlist\t%(title)s --cookies {COOKIES_PATH} {PLAYLIST_URL}`,
		"the listing prints one line per entry and the playlist title"
	)
end

local function checkFailedListings()
	local failedListing, exitFailure = listWith("false")
	local missingListing, startFailure = listWith("yt-dlp-that-does-not-exist")

	assert(
		not failedListing and exitFailure == "false exited with code 1",
		`a failing program reports its exit, got {exitFailure}`
	)
	assert(
		not missingListing and startFailure == "could not start yt-dlp-that-does-not-exist: FileNotFound",
		`a missing program reports that it could not start, got {startFailure}`
	)
end

local function checkListAsync()
	local failedListing, stderrFailure = listWith("checks/youtube.fake-error.sh")
	local listed, entries = listWith("checks/youtube.fake-listing.sh")

	assert(
		not failedListing and stderrFailure == "[youtube] abc: Video unavailable",
		`a failing program reports its stderr line, got {stderrFailure}`
	)

	assert(
		listed and entries[1].id == VIDEO_ID and entries[1].durationSeconds == 213,
		"a successful program returns its parsed entries"
	)
end

local function restoreMusicConfig()
	config.music.cookiesPath = originalCookiesPath
	config.music.ytDlpPath = originalYtDlpPath
end

checkLinks()
checkListing()
checkArguments()
checkFailedListings()
checkListAsync()
restoreMusicConfig()

print("youtube checks passed")
