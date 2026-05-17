local database = require("../singletons/database")

export type Tag = {
	name: string,
	content: string,
}

local tags = {}

function tags.getAll(): { Tag }
	return database:query("SELECT name, content FROM tags ORDER BY name"):all() :: any
end

function tags.get(name: string): Tag?
	return database:query(`SELECT name, content FROM tags WHERE name = '{database:escape(name)}'`):get() :: any
end

function tags.exists(name: string): boolean
	return database:query(`SELECT 1 FROM tags WHERE name = '{database:escape(name)}'`):get() ~= nil
end

function tags.create(name: string, content: string)
	database:exec(`INSERT INTO tags (name, content) VALUES ('{database:escape(name)}', '{database:escape(content)}')`)
end

function tags.update(name: string, content: string)
	database:exec(`UPDATE tags SET content = '{database:escape(content)}' WHERE name = '{database:escape(name)}'`)
end

function tags.delete(name: string)
	database:exec(`DELETE FROM tags WHERE name = '{database:escape(name)}'`)
end

return tags
