local builders = require("../../luau_packages/builders")

local config = require("../config")
local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local respondMessage = require("../utilities/respondMessage")

local CLOSE_BUTTON_PREFIX = "close_thread:"
local REQUEST_HELP_PREFIX = "request_help:"

local StaleThreadBumper = {}

StaleThreadBumper.Priority = 0

local bumpedThreadIds: { [string]: boolean } = {}
local helpRequestedThreadIds: { [string]: boolean } = {}

local function buildBumpMessage(idleDays: number, ownerId: string)
	return respondMessage({
		builders.message.components.container
			.new()
			:addComponent(
				builders.message.components.textDisplay
					.new()
					:setContent(
						`-# This thread has been inactive for **{idleDays} day{if idleDays == 1 then "" else "s"}**. If your question was answered, feel free to close this post. If you still need help, bump this thread with any additional details!`
					)
					:build()
			)
			:addComponent(
				builders.message.components.actionRow
					.new()
					:addComponent(
						builders.message.components.button
							.new()
							:setStyle("Green")
							:setLabel("Request Help")
							:setCustomId(`{REQUEST_HELP_PREFIX}{ownerId}`)
							:build()
					)
					:addComponent(
						builders.message.components.button
							.new()
							:setStyle("Red")
							:setLabel("Close Post")
							:setCustomId(`{CLOSE_BUTTON_PREFIX}{ownerId}`)
							:build()
					)
					:build()
			)
			:build(),
	})
end

local function runCheck()
	local guildResult = discordBot:getGuildAsync(config.guildId):await()

	if guildResult:isErr() then
		logger:warn(`StaleThreadBumper failed to fetch guild: {guildResult:unwrapErr()}`)

		return
	end

	local threadsResult = guildResult:unwrapOk():getThreadsAsync():await()

	if threadsResult:isErr() then
		logger:warn(`StaleThreadBumper failed to fetch threads: {threadsResult:unwrapErr()}`)

		return
	end

	local threads = threadsResult:unwrapOk()
	local thresholdSeconds = config.staleThreadThresholdSeconds
	local now = os.time()
	local bumped = 0

	for _, thread in threads do
		if thread.parentId ~= config.helpForumChannelId then
			continue
		end

		if bumpedThreadIds[thread.id] then
			continue
		end

		local metadata = thread.threadMetadata

		if not metadata then
			logger:warn(`StaleThreadBumper skipping thread {thread.id}: no threadMetadata`)

			continue
		end

		local lastActivity = metadata.archiveTimestamp.unixTimestamp
		local idleSeconds = now - lastActivity

		if idleSeconds < thresholdSeconds then
			continue
		end

		local idleDays = math.floor(idleSeconds / 86400)

		local sendResult = thread:createMessageAsync(buildBumpMessage(idleDays, thread.ownerId)):await()

		if sendResult:isErr() then
			logger:warn(`StaleThreadBumper failed to bump thread {thread.id}: {sendResult:unwrapErr()}`)

			continue
		end

		bumpedThreadIds[thread.id] = true
		bumped += 1

		logger:info(`Bumped stale thread {thread.id} (idle {idleDays}d)`)
	end

	if bumped > 0 then
		logger:info(`StaleThreadBumper bumped {bumped} thread(s)`)
	else
		logger:info("StaleThreadBumper found no stale threads")
	end
end

local function scheduleNext()
	zune.task.delay(config.staleThreadCheckIntervalSeconds, function()
		runCheck()
		scheduleNext()
	end)
end

function StaleThreadBumper:onReady()
	logger:info(
		`StaleThreadBumper starting - checking every {config.staleThreadCheckIntervalSeconds}s, threshold {config.staleThreadThresholdSeconds}s`
	)

	discordBot.onComponentInteraction:listen(function(interaction)
		if interaction.data.customId:find(REQUEST_HELP_PREFIX, 1, true) == 1 then
			local ownerId = interaction.data.customId:sub(#REQUEST_HELP_PREFIX + 1)
			local clickerId = if interaction.member then interaction.member.user.id else interaction.user.id
			local threadId = interaction.channelId

			interaction:acknowledgeAsync():await()

			if helpRequestedThreadIds[threadId] then
				return
			end

			if clickerId ~= ownerId then
				return
			end

			helpRequestedThreadIds[threadId] = true

			local channelResult = discordBot:getChannelAsync(threadId):await()

			if channelResult:isErr() then
				logger:warn(`request_help failed to fetch channel: {channelResult:unwrapErr()}`)
				helpRequestedThreadIds[threadId] = nil

				return
			end

			local channel = channelResult:unwrapOk()

			if channel.threadMetadata and channel.threadMetadata.archived then
				logger:info(`request_help skipped ping for already-archived thread {threadId}`)

				return
			end

			local pingResult = channel
				:createMessageAsync(
					builders.message.message
						.new()
						:setContent(`<@&{config.helpersRoleId}> help has been requested in this thread!`)
						:build()
				)
				:await()

			if pingResult:isErr() then
				logger:warn(`request_help failed to send ping: {pingResult:unwrapErr()}`)
				helpRequestedThreadIds[threadId] = nil
			else
				logger:info(`Help requested in thread {threadId}`)
			end

			return
		end

		if not interaction.data.customId:find(CLOSE_BUTTON_PREFIX, 1, true) then
			return
		end

		local ownerId = interaction.data.customId:sub(#CLOSE_BUTTON_PREFIX + 1)
		local clickerId = if interaction.member then interaction.member.user.id else interaction.user.id

		interaction:acknowledgeAsync():await()

		if clickerId ~= ownerId then
			return
		end

		local channelResult = discordBot:getChannelAsync(interaction.channelId):await()

		if channelResult:isErr() then
			logger:warn(`close_thread failed to fetch channel: {channelResult:unwrapErr()}`)

			return
		end

		local channel = channelResult:unwrapOk()
		local deleteAt = os.time() + 5

		local notifyResult = channel
			:createMessageAsync(
				builders.message.message.new():setContent(`This post will be deleted <t:{deleteAt}:R>.`):build()
			)
			:await()

		if notifyResult:isErr() then
			logger:warn(`close_thread failed to send deletion notice: {notifyResult:unwrapErr()}`)
		end

		zune.task.delay(5, function()
			local deleteResult = channel:deleteChannelAsync():await()

			if deleteResult:isErr() then
				logger:warn(`close_thread failed to delete thread {interaction.channelId}: {deleteResult:unwrapErr()}`)
			else
				logger:info(`Thread {interaction.channelId} deleted by owner {ownerId}`)
			end
		end)
	end)

	runCheck()
	scheduleNext()
end

export type StaleThreadBumper = typeof(StaleThreadBumper)

return StaleThreadBumper
