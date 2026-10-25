local musicQueue = require("../src/utilities/musicQueue")

local function track(id: string, durationSeconds: number?): musicQueue.Track
	return { id = id, title = `Song {id}`, durationSeconds = durationSeconds, requesterId = "42" }
end

local function ids(tracks: { musicQueue.Track }): string
	local parts = {}

	for _, entry in tracks do
		table.insert(parts, entry.id)
	end

	return table.concat(parts, ",")
end

local function lowest(low: number, _high: number): number
	return low
end

local function highest(_low: number, high: number): number
	return high
end

local function checkConversionAndRemove()
	local converted = musicQueue.toTracks({
		{ id = "x", title = "X", durationSeconds = 10 },
		{ id = "y", title = "Y" },
	}, "42")
	local queue = { track("a", 60), track("b", 120), track("c"), track("d", 30) }
	local removed = musicQueue.remove(queue, 2)

	assert(#converted == 2, "toTracks keeps every entry")
	assert(
		converted[1].requesterId == "42" and converted[2].requesterId == "42",
		"toTracks tags each track with the requester"
	)
	assert(
		converted[1].durationSeconds == 10 and not converted[2].durationSeconds,
		"toTracks keeps durations, nil included"
	)
	assert(removed and removed.id == "b", "remove takes the song at position 2")
	assert(ids(queue) == "a,c,d", `remove keeps the rest in order, got {ids(queue)}`)
	assert(not musicQueue.remove(queue, 0), "remove refuses position 0")
	assert(not musicQueue.remove(queue, 4), "remove refuses a position past the end")
	assert(not musicQueue.remove(queue, 1.5), "remove refuses a fractional position")
	assert(ids(queue) == "a,c,d", "a refused remove changes nothing")
end

local function checkShuffle()
	local shuffled = { track("a"), track("b"), track("c"), track("d") }
	local many = {}
	local seen = {}
	local seenCount = 0

	assert(musicQueue.shuffle(shuffled, lowest) == 4, "shuffle returns how many songs it shuffled")
	assert(ids(shuffled) == "a,b,c,d", `swapping each song with itself keeps the order, got {ids(shuffled)}`)
	musicQueue.shuffle(shuffled, highest)
	assert(ids(shuffled) == "d,a,b,c", `swapping each song with the last gives d,a,b,c, got {ids(shuffled)}`)
	assert(musicQueue.shuffle({}, math.random) == 0, "an empty queue shuffles 0 songs")

	for index = 1, 30 do
		table.insert(many, track(`t{index}`))
	end

	musicQueue.shuffle(many, math.random)

	for _, entry in many do
		seen[entry.id] = true
	end

	for _ in seen do
		seenCount += 1
	end

	assert(#many == 30 and seenCount == 30, "a random shuffle keeps every song once")
end

local function checkPages()
	local long = {}

	for index = 1, 23 do
		table.insert(long, track(`t{index}`, if index == 5 then nil else 60))
	end

	local first = musicQueue.page(long, track("now", 200), 1, 10)
	local last = musicQueue.page(long, nil, 3, 10)
	local beyond = musicQueue.page(long, nil, 99, 10)
	local before = musicQueue.page(long, nil, 0, 10)
	local empty = musicQueue.page({}, nil, 1, 10)

	assert(first.page == 1 and first.pageCount == 3 and first.total == 23, "23 songs make 3 pages of 10")
	assert(
		first.firstPosition == 1 and #first.tracks == 10 and first.tracks[1].id == "t1",
		"page 1 starts at position 1"
	)
	assert(
		first.totalSeconds == 22 * 60 and first.unknownCount == 1,
		"totals add known durations and count the unknown"
	)
	assert(first.current and first.current.id == "now", "a page carries the current song")
	assert(
		last.firstPosition == 21 and #last.tracks == 3 and last.tracks[3].id == "t23",
		"page 3 holds positions 21 to 23"
	)
	assert(
		beyond.page == 3 and beyond.firstPosition == 21 and #beyond.tracks == 3,
		"a page past the end clamps to the last page"
	)
	assert(before.page == 1 and before.firstPosition == 1, "a page before the start clamps to the first page")
	assert(
		empty.page == 1 and empty.pageCount == 1 and empty.total == 0 and #empty.tracks == 0,
		"an empty queue is one empty page"
	)
end

local function checkTiming()
	local timing: musicQueue.Timing = { pausedSeconds = 0 }

	assert(musicQueue.elapsedSeconds(timing, 500) == 0, "nothing started reads 0 seconds")
	musicQueue.startTiming(timing, 1000)
	assert(musicQueue.elapsedSeconds(timing, 1030) == 30, "30 seconds in")
	musicQueue.pauseTiming(timing, 1030)
	assert(musicQueue.elapsedSeconds(timing, 1100) == 30, "a pause stops the clock")
	musicQueue.resumeTiming(timing, 1100)
	assert(musicQueue.elapsedSeconds(timing, 1110) == 40, "the clock runs again after resume")
	musicQueue.pauseTiming(timing, 1110)
	musicQueue.resumeTiming(timing, 1400)
	assert(musicQueue.elapsedSeconds(timing, 1405) == 45, "two pauses add up")
	musicQueue.resumeTiming(timing, 1500)
	assert(musicQueue.elapsedSeconds(timing, 1505) == 145, "a resume without a pause changes nothing")
	musicQueue.startTiming(timing, 2000)
	assert(
		musicQueue.elapsedSeconds(timing, 2010) == 10 and timing.pausedSeconds == 0,
		"a new song starts the clock again"
	)
end

checkConversionAndRemove()
checkShuffle()
checkPages()
checkTiming()
print("musicQueue checks passed")
