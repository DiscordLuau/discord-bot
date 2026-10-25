local database = require("../src/singletons/database")

database:exec("CREATE TABLE IF NOT EXISTS check_writes (id INTEGER PRIMARY KEY)")
database:exec("INSERT INTO check_writes DEFAULT VALUES")

local synchronous = database.db:query("PRAGMA synchronous"):all()[1]
local header = zune.fs.readFile("data/bot.db")
local otherConnection = zune.sqlite.open("data/bot.db")
local readable, rows = pcall(function()
	return otherConnection:query("SELECT COUNT(*) AS count FROM check_writes"):all()
end)

otherConnection:close()
database:exec("DROP TABLE check_writes")

assert(
	string.byte(header, 19) == 2,
	`the database file is in WAL mode, its header says version {string.byte(header, 19)}`
)
assert(synchronous and synchronous.synchronous == 1, "the database syncs at NORMAL, not on every write")
assert(readable and rows[1].count >= 1, `a second connection sees the committed write, got {tostring(rows)}`)

print("database checks passed")
