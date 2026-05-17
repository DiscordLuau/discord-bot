local builders = require("../../luau_packages/builders")

local database = require("../singletons/database")
local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local respondMessage = require("../utilities/respondMessage")

local RESPONSE_FOOTER =
	"-# If something is wrong or missing, please open an issue on the [GitHub repository](https://github.com/DiscordLuau/discord-bot/issues)."

local AutoResponder = {}

AutoResponder.Priority = 0

function AutoResponder:onReady()
	discordBot.onMessage:listen(function(message)
		if not message.content or message.content == "" then
			return
		end

		if message.author and message.author.bot then
			return
		end

		local lowercaseContent = message.content:lower()
		local rows = database:query("SELECT keyphrases, content, reply FROM autoresponses"):all()

		for _, row in rows do
			local keyphrases: { string } = zune.serde.json.decode(row.keyphrases :: string)

			for _, keyphrase in keyphrases do
				if lowercaseContent:find(keyphrase:lower(), 1, true) then
					local builtMessage = respondMessage({
						builders.message.components.container
							.new()
							:addComponent(
								builders.message.components.textDisplay
									.new()
									:setContent(row.content :: string)
									:build()
							)
							:addComponent(
								builders.message.components.separator.new():setDivider(true):setSpacing(1):build()
							)
							:addComponent(
								builders.message.components.textDisplay.new():setContent(RESPONSE_FOOTER):build()
							)
							:build(),
					})

					if row.reply == 1 then
						message:replyAsync(builtMessage):poll()
					else
						local channelResult = discordBot:getChannelAsync(message.channelId):await()

						if channelResult:isErr() then
							logger:warn(
								`Failed to fetch channel {message.channelId} for autoresponse: {channelResult:unwrapErr()}`
							)
						else
							channelResult:unwrapOk():createMessageAsync(builtMessage):poll()
						end
					end

					logger:info(`Auto-responded to message {message.id} (matched keyphrase "{keyphrase}")`)

					break
				end
			end
		end
	end)
end

export type AutoResponder = typeof(AutoResponder)

return AutoResponder
