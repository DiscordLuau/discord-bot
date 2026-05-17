local classes = require("../../luau_packages/classes")

local config = require("../config")
local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")
local registry = require("../objects/registry")

local hotRequire = require("../utilities/hotRequire")

local flushCommandsThread: thread?
local testingGuild

local Commands = {}

Commands.Priority = 0

function Commands:registerAsync(commandClass: classes.Command)
	logger:debug(`Registering command '{commandClass.name}'`)

	registry.commandObjects[commandClass.name] = commandClass

	if flushCommandsThread then
		logger:debug(`Debouncing flush - cancelling existing flush thread`)

		zune.task.cancel(flushCommandsThread)
	end

	flushCommandsThread = zune.task.delay(1, function()
		local commandsArray = {}

		for _, commandObject in registry.commandObjects do
			table.insert(commandsArray, commandObject)
		end

		logger:info(`Flushing {#commandsArray} command(s) to Discord`)

		testingGuild
			:overwriteSlashCommandsAsync(commandsArray)
			:after(function(result)
				if result:isErr() then
					logger:warn(`Failed to overwrite guild slash commands: {result:unwrapErr()}`)
				end
			end)
			:poll()

		logger:info(`Successfully flushed {#commandsArray} command(s) to Discord`)
	end)
end

function Commands:isLoaded(path: string)
	return not not registry.commandPathsLoaded[path]
end

function Commands:loadCommand(path: string)
	if self:isLoaded(path) then
		logger:warn(`Attempted to load already-loaded command at '{path}' - skipping`)

		return
	end

	logger:debug(`Loading command at '{path}'`)

	local commandModule = hotRequire(path)

	if not commandModule then
		logger:warn(`hotRequire returned nil for '{path}' - skipping load`)

		return
	end

	registry.commandCleanupFns[path] = commandModule()
	registry.commandPathsLoaded[path] = true

	logger:info(`Loaded command at '{path}'`)
end

function Commands:unloadCommand(path: string)
	local cleanupFunction = registry.commandCleanupFns[path]

	if not cleanupFunction then
		logger:warn(`Attempted to unload command at '{path}' but no cleanup function found - skipping`)

		return
	end

	logger:debug(`Unloading command at '{path}'`)

	cleanupFunction()

	registry.commandCleanupFns[path] = nil
	registry.commandPathsLoaded[path] = nil

	logger:info(`Unloaded command at '{path}'`)
end

function Commands:reloadCommand(path: string)
	logger:info(`Reloading command at '{path}'`)

	self:unloadCommand(path)
	self:loadCommand(path)

	logger:debug(`Reload complete for '{path}'`)
end

function Commands:loadDirectory(path: string)
	logger:info(`Loading commands from directory '{path}'`)

	local count = 0

	for _, entry in zune.fs.entries(path) do
		if entry.kind ~= "file" then
			if entry.kind == "directory" then
				self:loadDirectory(`{path}/{entry.name}`)
			else
				logger:debug(`Skipping non-file entry '{entry.name}' (kind: '{entry.kind}')`)
			end

			continue
		end

		if entry.name == "meta.luau" then
			logger:debug(`Skipping meta file '{entry.name}'`)

			continue
		end

		local filePath = `{path}/{entry.name}`

		if self:isLoaded(filePath) then
			logger:debug(`'{filePath}' already loaded - reloading`)

			self:reloadCommand(filePath)
		else
			self:loadCommand(filePath)
		end

		count += 1
	end

	logger:info(`Finished loading directory '{path}' - processed {count} command(s)`)
end

function Commands:onReady()
	logger:info("Commands singleton ready - loading command directory")

	testingGuild = discordBot:getGuildAsync(config.guildId):await():unwrapOk()

	self:loadDirectory("src/commands")
end

export type Commands = typeof(Commands)

return Commands
