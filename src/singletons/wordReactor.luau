local config = require("../config")
local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local WordReactor = {}

WordReactor.Priority = 0

local function escapePattern(text: string): string
	return text:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
end

function WordReactor:onReady()
	discordBot.onMessage:listen(function(message)
		if not message.content or message.content == "" then
			return
		end

		local lowercaseContent = message.content:lower()

		for _, entry in config.wordReactions do
			local wordPattern = "%f[%w]" .. escapePattern(entry.pattern:lower()) .. "%f[%W]"

			if lowercaseContent:find(wordPattern) then
				message:addReactionAsync(entry.emoji):poll()

				logger:info(`Reacted to message {message.id} with {entry.emoji} (matched "{entry.pattern}")`)
			end
		end
	end)
end

export type WordReactor = typeof(WordReactor)

return WordReactor
