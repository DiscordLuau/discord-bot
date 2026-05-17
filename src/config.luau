local config = {}

config.guildId = "1273035219561091193"

config.guidelinesChannelId = "1273037657416404992"
config.guidelinesMessageId = "1505194625739260087"

config.systemsChannelId = "1273037843995955374"

config.discordUserIds = {
	developers = {
		"893762371770802227",
		"685566749516628033",
	},
}

config.discordRoleIds = {
	adminRoles = {
		"1275463732276756480",
	},
}

config.permissions = {
	developer = {
		userIds = config.discordUserIds.developers,
		roleIds = {},
	},
	admin = {
		userIds = {},
		roleIds = config.discordRoleIds.adminRoles,
	},
}

config.helpForumChannelId = "1273041931210985533"
config.helpersRoleId = "1313773219156594689"
config.staleThreadThresholdSeconds = 3 * 24 * 60 * 60
config.staleThreadCheckIntervalSeconds = 6 * 60 * 60

config.wordReactions = {
	{ pattern = "british", emoji = "🇬🇧" },
	{ pattern = "meow", emoji = "🐈" },
	{ pattern = "woof", emoji = "🐕" },
	{ pattern = "fr", emoji = "🏴󠁧󠁢󠁳󠁣󠁴󠁿" },
}

return config
