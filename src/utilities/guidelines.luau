local database = require("../singletons/database")

export type Guideline = {
	id: number,
	text: string,
	hidden: number,
}

local guidelines = {}

function guidelines.getAll(): { Guideline }
	return database:query("SELECT id, text, hidden FROM guidelines ORDER BY id"):all() :: any
end

function guidelines.get(id: number): Guideline?
	return database:query(`SELECT id, text, hidden FROM guidelines WHERE id = {id}`):get() :: any
end

function guidelines.create(text: string): number
	local result = database:query(
		`INSERT INTO guidelines (text, hidden) VALUES ('{database:escape(text)}', 0)`
	):run()

	return result.last_insert_row_id
end

function guidelines.delete(id: number)
	database:exec(`DELETE FROM guidelines WHERE id = {id}`)
end

function guidelines.setHidden(id: number, hidden: boolean)
	local hiddenInt = if hidden then 1 else 0

	database:exec(`UPDATE guidelines SET hidden = {hiddenInt} WHERE id = {id}`)
end

return guidelines
