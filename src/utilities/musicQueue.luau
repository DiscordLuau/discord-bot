local youtube = require("../utilities/youtube")

local musicQueue = {}

function musicQueue.toTracks(entries: { youtube.Entry }, requesterId: string): { Track }
	local tracks = {}

	for _, entry in entries do
		table.insert(tracks, {
			id = entry.id,
			title = entry.title,
			durationSeconds = entry.durationSeconds,
			requesterId = requesterId,
		})
	end

	return tracks
end

function musicQueue.remove(queue: { Track }, position: number): Track?
	local valid = position >= 1 and position <= #queue and position % 1 == 0

	return if valid then table.remove(queue, position) else nil
end

function musicQueue.shuffle(queue: { Track }, random: (number, number) -> number): number
	for index in queue do
		local swapIndex = random(index, #queue)

		queue[index], queue[swapIndex] = queue[swapIndex], queue[index]
	end

	return #queue
end

function musicQueue.page(queue: { Track }, current: Track?, page: number, pageSize: number): QueuePage
	local total = #queue
	local pageCount = math.max(1, math.ceil(total / pageSize))
	local clampedPage = math.clamp(math.floor(page), 1, pageCount)
	local firstPosition = (clampedPage - 1) * pageSize + 1
	local lastPosition = math.min(firstPosition + pageSize - 1, total)
	local totalSeconds = 0
	local unknownCount = 0

	for _, track in queue do
		if track.durationSeconds then
			totalSeconds += track.durationSeconds
		else
			unknownCount += 1
		end
	end

	return {
		current = current,
		tracks = table.move(queue, firstPosition, lastPosition, 1, {}),
		page = clampedPage,
		pageCount = pageCount,
		firstPosition = firstPosition,
		total = total,
		totalSeconds = totalSeconds,
		unknownCount = unknownCount,
	}
end

function musicQueue.startTiming(timing: Timing, now: number)
	timing.startedAt = now
	timing.pausedAt = nil
	timing.pausedSeconds = 0
end

function musicQueue.pauseTiming(timing: Timing, now: number)
	timing.pausedAt = now
end

function musicQueue.resumeTiming(timing: Timing, now: number)
	local pausedAt = timing.pausedAt

	timing.pausedSeconds += if pausedAt then now - pausedAt else 0
	timing.pausedAt = nil
end

function musicQueue.elapsedSeconds(timing: Timing, now: number): number
	local startedAt = timing.startedAt
	local pausedAt = timing.pausedAt
	local pausedNow = if pausedAt then now - pausedAt else 0

	return if startedAt then math.max(0, now - startedAt - timing.pausedSeconds - pausedNow) else 0
end

export type Track = {
	id: string,
	title: string,
	durationSeconds: number?,
	requesterId: string,
}

export type Timing = {
	startedAt: number?,
	pausedAt: number?,
	pausedSeconds: number,
}

export type QueuePage = {
	current: Track?,
	tracks: { Track },
	page: number,
	pageCount: number,
	firstPosition: number,
	total: number,
	totalSeconds: number,
	unknownCount: number,
}

return musicQueue
