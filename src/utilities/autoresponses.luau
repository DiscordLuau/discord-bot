local database = require("../singletons/database")

export type Autoresponse = {
	id: number,
	keyphrases: string,
	content: string,
	reply: number,
}

local autoresponses = {}

function autoresponses.getAll(): { Autoresponse }
	return database:query("SELECT id, keyphrases, content, reply FROM autoresponses ORDER BY id"):all() :: any
end

function autoresponses.exists(id: number): boolean
	return database:query(`SELECT 1 FROM autoresponses WHERE id = {id}`):get() ~= nil
end

function autoresponses.create(keyphrases: { string }, content: string, reply: boolean): number
	local escapedKeyphrases = database:escape(zune.serde.json.encode(keyphrases))
	local escapedContent = database:escape(content)
	local replyInt = if reply then 1 else 0

	local result = database:query(
		`INSERT INTO autoresponses (keyphrases, content, reply) VALUES ('{escapedKeyphrases}', '{escapedContent}', {replyInt})`
	):run()

	return result.last_insert_row_id
end

function autoresponses.delete(id: number)
	database:exec(`DELETE FROM autoresponses WHERE id = {id}`)
end

return autoresponses
