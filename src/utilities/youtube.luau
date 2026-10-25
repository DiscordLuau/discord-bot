local config = require("../config")
local logger = require("../objects/logger")

local ENTRY_TEMPLATE = "%(id)s\t%(duration)s\t%(title)s"
local PLAYLIST_TEMPLATE = "playlist:#playlist\t%(title)s"
local VIDEO_ID_LENGTH = 11
local WATCH_URL = "https://www.youtube.com/watch?v="
local PLAYLIST_URL = "https://www.youtube.com/playlist?list="
local SITES = {
	["youtube.com"] = "youtube",
	["www.youtube.com"] = "youtube",
	["m.youtube.com"] = "youtube",
	["music.youtube.com"] = "music",
	["youtu.be"] = "short",
}

local youtube = {}

local function queryValue(query: string, name: string): string?
	for pair in string.gmatch(query, "[^&]+") do
		local key, value = string.match(pair, "^([^=]*)=(.*)$")

		if key == name then
			return value
		end
	end

	logger:debug(`youtube no {name} in the query`)

	return
end

local function isVideoId(id: string?): boolean
	local valid = id and #id == VIDEO_ID_LENGTH and string.find(id, "^[%w_%-]+$")

	return if valid then true else false
end

local function isPlaylistId(id: string?): boolean
	local valid = id and string.find(id, "^[%w_%-]+$")

	return if valid then true else false
end

function youtube.parseLink(link: string): Link?
	local trimmed = string.match(link, "^%s*(.-)%s*$") or ""
	local address = string.match(trimmed, "^https?://(.*)$") or trimmed
	local host, route, query = string.match(address, "^([^/?#]+)([^?#]*)%??([^#]*)")
	local site = if host then SITES[string.lower(host)] else nil
	local videoId = if site == "short"
		then string.match(route or "", "^/([^/]+)$")
		elseif (site == "youtube" or site == "music") and route == "/watch" then queryValue(query or "", "v")
		elseif site == "youtube" then string.match(route or "", "^/shorts/([^/]+)$")
		else nil
	local playlistId = if site == "youtube" and route == "/playlist" then queryValue(query or "", "list") else nil

	if isVideoId(videoId) then
		return { kind = "video", url = WATCH_URL .. (videoId :: string) }
	end

	if isPlaylistId(playlistId) then
		return { kind = "playlist", url = PLAYLIST_URL .. (playlistId :: string) }
	end

	logger:debug(`youtube not a YouTube video or playlist link: {link}`)

	return
end

function youtube.listArguments(link: Link): { string }
	local arguments = {
		"--flat-playlist",
		"--simulate",
		"--no-warnings",
		"--ignore-no-formats-error",
		"--print",
		ENTRY_TEMPLATE,
		"--print",
		PLAYLIST_TEMPLATE,
	}
	local cookiesPath = config.music.cookiesPath

	if cookiesPath then
		table.insert(arguments, "--cookies")
		table.insert(arguments, cookiesPath)
	end

	table.insert(arguments, link.url)

	return arguments
end

function youtube.parseListing(output: string): ({ Entry }, string?)
	local entries: { Entry } = {}
	local playlistTitle: string?

	for line in string.gmatch(output, "[^\n]+") do
		local listTitle = string.match(line, "^#playlist\t(.*)$")
		local id, duration, title = string.match(line, "^([%w_%-]+)\t([^\t]*)\t(.*)$")

		if listTitle then
			playlistTitle = listTitle
		elseif id then
			table.insert(entries, { id = id, title = title :: string, durationSeconds = tonumber(duration) })
		else
			logger:warn(`youtube skipped a yt-dlp listing line it could not read: {line}`)
		end
	end

	return entries, playlistTitle
end

function youtube.errorLine(text: string): string?
	local last: string?

	for line in string.gmatch(text, "[^\r\n]+") do
		if string.find(line, "%S") then
			last = line
		end
	end

	if not last then
		logger:debug(`youtube no error line in the output`)

		return
	end

	return (string.gsub(last, "^ERROR: ", ""))
end

function youtube.listAsync(link: Link): (boolean, { Entry } | string, string?)
	local ytDlpPath = config.music.ytDlpPath
	local arguments = youtube.listArguments(link)
	local runProcess = zune.process.run :: (string, { string }?) -> any
	local ran, result = pcall(runProcess, ytDlpPath, arguments)

	if not ran then
		logger:warn(`youtube could not start {ytDlpPath}: {result}`)

		return false, `could not start {ytDlpPath}: {result}`
	end

	if not result.ok then
		local failure = youtube.errorLine(result.stderr) or `{ytDlpPath} exited with code {result.code}`

		logger:info(`youtube listing {link.url} failed: {failure}`)

		return false, failure
	end

	local entries, playlistTitle = youtube.parseListing(result.stdout)

	logger:info(`youtube listed {#entries} song(s) from {link.url}`)

	return true, entries, playlistTitle
end

function youtube.streamArguments(id: string): { string }
	local arguments = { "-f", "251/bestaudio", "--no-playlist" }
	local cookiesPath = config.music.cookiesPath

	if cookiesPath then
		table.insert(arguments, "--cookies")
		table.insert(arguments, cookiesPath)
	end

	table.insert(arguments, "-o")
	table.insert(arguments, "-")
	table.insert(arguments, WATCH_URL .. id)

	return arguments
end

export type Link = { kind: "video" | "playlist", url: string }

export type Entry = { id: string, title: string, durationSeconds: number? }

return youtube
