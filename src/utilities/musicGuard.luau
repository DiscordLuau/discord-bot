local logger = require("../objects/logger")
local music = require("../singletons/music")
local voiceStates = require("../singletons/voiceStates")

local respondCommand = require("../utilities/respondCommand")

return function(interaction: any, commandName: string): music.Session?
	local member = interaction.member

	if not member then
		logger:debug(`/{commandName}: no guild member; this command works only in the server`)
		interaction:messageAsync(respondCommand("This command works only in the server", true)):poll()

		return
	end

	local session = music.Session
	local userId = member.user.id

	if not session then
		logger:debug(`/{commandName}: nothing is playing`)
		interaction:messageAsync(respondCommand("Nothing is playing", true)):poll()

		return
	end

	if voiceStates:getChannel(userId) ~= session.channelId then
		logger:debug(`/{commandName}: {userId} is not in voice channel {session.channelId}`)
		interaction:messageAsync(respondCommand(`Join <#{session.channelId}> to control the music`, true)):poll()

		return
	end

	return session
end
