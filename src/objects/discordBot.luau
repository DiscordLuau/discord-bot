local discord = require("../../luau_packages/discord")
local builders = require("../../luau_packages/builders")

local env = require("../../.env")

local DISCORD_BOT_INTENTS = builders.intents
	.new({
		"Guilds",
		"GuildMessages",
		"MessageContent",
	})
	:build()

return discord.bot.new({
	token = env.DISCORD_BOT_TOKEN,
	intents = DISCORD_BOT_INTENTS,
	reconnect = true,
})
