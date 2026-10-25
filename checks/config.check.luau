local config = require("../src/config")

assert(config.music, "config.music exists")
assert(config.music.ytDlpPath == "yt-dlp", "yt-dlp is found on PATH")
assert(config.music.idleLeaveSeconds == 120, "the bot leaves voice after 2 minutes idle")
assert(config.music.queuePageSize == 10, "/queue shows 10 songs a page")
assert(
	config.music.cookiesPath == zune.process.env.YOUTUBE_COOKIES_PATH,
	"the cookies path comes from YOUTUBE_COOKIES_PATH"
)

print("config checks passed")
