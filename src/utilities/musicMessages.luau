local builders = require("../../luau_packages/builders")

local formatDuration = require("../utilities/formatDuration")
local musicQueue = require("../utilities/musicQueue")
local respondMessage = require("../utilities/respondMessage")

local QUEUE_BUTTON_PREFIX = "music:queue:"
local COOKIE_REFUSAL = "Sign in to confirm you"
local ZERO_WIDTH_SPACE = utf8.char(0x200B)
local FAILURE_PREFIXES = {
	"^audio source failed: ",
	"^audio stream read failed: ",
	"^%S+ exited with code %-?%d+: ",
	"^ERROR: ",
}

local musicMessages = {}

local function durationText(track: Track): string
	return if track.durationSeconds then formatDuration(track.durationSeconds) else "unknown length"
end

local function plural(count: number, noun: string): string
	return `{count} {noun}{if count == 1 then "" else "s"}`
end

local function queueButton(label: string, targetPage: number, disabled: boolean)
	return builders.message.components.button
		.new()
		:setStyle("Grey")
		:setLabel(label)
		:setCustomId(`{QUEUE_BUTTON_PREFIX}{targetPage}`)
		:setDisabled(disabled)
		:build()
end

function musicMessages.escape(text: string): string
	local escaped = string.gsub(text, "[\\%*_~`|>%[%]]", "\\%0")
	local unpinged = string.gsub(escaped, "@", `@{ZERO_WIDTH_SPACE}`)

	return unpinged
end

function musicMessages.trackLine(track: Track): string
	return `**{musicMessages.escape(track.title)}** ({durationText(track)})`
end

function musicMessages.queuedTrack(track: Track, position: number?): string
	return if position
		then `Queued {musicMessages.trackLine(track)}, position {position}`
		else `Playing {musicMessages.trackLine(track)}`
end

function musicMessages.queuedPlaylist(count: number, playlistTitle: string?): string
	return if playlistTitle
		then `Queued {plural(count, "song")} from **{musicMessages.escape(playlistTitle)}**`
		else `Queued {plural(count, "song")}`
end

function musicMessages.notice(content: string): builders.messageJSON
	return builders.message.message.new():setContent(content):setAllowedMentions({ parse = {} }):build()
end

function musicMessages.nowPlaying(track: Track): builders.messageJSON
	return musicMessages.notice(`Now playing {musicMessages.trackLine(track)}, requested by <@{track.requesterId}>`)
end

function musicMessages.nowPlayingStatus(track: Track, elapsedSeconds: number, paused: boolean): string
	local position = formatDuration(elapsedSeconds)

	return if paused
		then `Paused {musicMessages.trackLine(track)} at {position}`
		else `Now playing {musicMessages.trackLine(track)}, {position} in`
end

function musicMessages.isCookieRefusal(failure: string): boolean
	return if string.find(failure, COOKIE_REFUSAL, 1, true) then true else false
end

function musicMessages.failureReason(failure: string): string
	local reason = failure

	for _, prefix in FAILURE_PREFIXES do
		reason = string.gsub(reason, prefix, "")
	end

	return reason
end

function musicMessages.trackFailed(track: Track, failure: string): string
	return if musicMessages.isCookieRefusal(failure)
		then "YouTube refused the download, the bot's YouTube cookies need refreshing"
		else `Couldn't play {musicMessages.trackLine(track)}: {musicMessages.escape(
			musicMessages.failureReason(failure)
		)}`
end

function musicMessages.leftIdle(seconds: number): string
	return `Left voice after {formatDuration(seconds)} with nothing to play`
end

function musicMessages.leftEmpty(seconds: number): string
	return `Left voice after {formatDuration(seconds)} with nobody listening`
end

function musicMessages.disconnected(detail: string): string
	return `Disconnected from voice: {detail}`
end

function musicMessages.queuePage(page: musicQueue.QueuePage): builders.messageJSON
	local lines = {}
	local unknownNote = if page.unknownCount > 0 then ` plus {page.unknownCount} of unknown length` else ""

	if page.current then
		table.insert(lines, `Now playing: {musicMessages.trackLine(page.current)}`)
	end

	if page.total == 0 then
		table.insert(lines, "Nothing is queued")
	else
		table.insert(lines, `Up next: {plural(page.total, "song")}, {formatDuration(page.totalSeconds)}{unknownNote}`)
	end

	for index, track in page.tracks do
		table.insert(lines, `{page.firstPosition + index - 1}. {musicMessages.trackLine(track)}`)
	end

	table.insert(lines, `-# Page {page.page} of {page.pageCount}`)

	return respondMessage({
		builders.message.components.container
			.new()
			:addComponent(builders.message.components.textDisplay.new():setContent(table.concat(lines, "\n")):build())
			:addComponent(
				builders.message.components.actionRow
					.new()
					:addComponent(queueButton("Previous", page.page - 1, page.page == 1))
					:addComponent(queueButton("Next", page.page + 1, page.page == page.pageCount))
					:build()
			)
			:build(),
	})
end

function musicMessages.queueClosed(): builders.messageJSON
	return respondMessage({
		builders.message.components.container
			.new()
			:addComponent(builders.message.components.textDisplay.new():setContent("Nothing is playing"):build())
			:build(),
	})
end

function musicMessages.queueButtonPage(customId: string?): number?
	local digits = if customId then string.match(customId, `^{QUEUE_BUTTON_PREFIX}(%d+)$`) else nil

	return if digits then tonumber(digits) else nil
end

type Track = musicQueue.Track

return musicMessages
