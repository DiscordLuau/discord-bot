local logger = require("../objects/logger")

local DataBase = {}

DataBase.Priority = 1
DataBase.db = zune.sqlite.open("bot.db")

function DataBase:query(sql: string)
	return self.db:query(sql)
end

function DataBase:exec(sql: string, args: { [string]: any }?)
	return self.db:exec(sql, args)
end

function DataBase:escape(text: string): string
	return text:gsub("'", "''")
end

function DataBase:getConfig(key: string): string
	local row = self.db:query(`SELECT value FROM config WHERE key = '{self:escape(key)}'`):get()

	return if row then row.value :: string else ""
end

function DataBase:setConfig(key: string, value: string)
	self.db:exec(`INSERT OR REPLACE INTO config (key, value) VALUES ('{self:escape(key)}', '{self:escape(value)}')`)
end

function DataBase:onReady()
	self.db:exec([[
		CREATE TABLE IF NOT EXISTS tags (
			name TEXT PRIMARY KEY,
			content TEXT NOT NULL
		)
	]])

	self.db:exec([[
		CREATE TABLE IF NOT EXISTS autoresponses (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			keyphrases TEXT NOT NULL,
			content TEXT NOT NULL,
			reply INTEGER NOT NULL DEFAULT 1
		)
	]])

	self.db:exec([[
		CREATE TABLE IF NOT EXISTS guidelines (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			text TEXT NOT NULL,
			hidden INTEGER NOT NULL DEFAULT 0
		)
	]])

	self.db:exec([[
		CREATE TABLE IF NOT EXISTS config (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL
		)
	]])

	self.db:exec([[
		CREATE TABLE IF NOT EXISTS logs (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			level TEXT NOT NULL,
			level_index INTEGER NOT NULL,
			message TEXT NOT NULL,
			time INTEGER NOT NULL
		)
	]])

	self.db:exec([[
		CREATE TABLE IF NOT EXISTS process_snapshots (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			time INTEGER NOT NULL,
			resident_set_size_in_kb INTEGER NOT NULL,
			cpu_time_in_seconds REAL NOT NULL,
			memory_used_in_kb INTEGER NOT NULL DEFAULT 0
		)
	]])

	self.db:exec(`DELETE FROM logs WHERE time < {os.time() - 30 * 86400}`)
	self.db:exec(`DELETE FROM process_snapshots WHERE time < {os.time() - 86400}`)

	logger:info("Database ready")
end

export type DataBase = typeof(DataBase)

return DataBase
