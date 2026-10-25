local database = require("../src/singletons/database")

local synchronous = database:query("PRAGMA synchronous"):get()

assert(database.JournalMode == "wal", `the database runs in WAL mode, got {database.JournalMode}`)
assert(synchronous and synchronous.synchronous == 1, "the database syncs at NORMAL, not on every write")

print("database checks passed")
