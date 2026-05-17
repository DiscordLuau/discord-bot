local builders = require("../../../luau_packages/builders")

local commands = require("../../singletons/commands")
local discordBot = require("../../objects/discordBot")
local logger = require("../../objects/logger")

local binder = require("../../utilities/binder")
local handleInteraction = require("../../utilities/handleInteraction")
local respondCommand = require("../../utilities/respondCommand")

local function reply(interaction: any, content: string)
	interaction:messageAsync(respondCommand(content)):poll()
end

local function resolveCommandPath(input: string): string?
	if input:find("/") then
		return input
	end

	local target = input:gsub("%.luau$", "") .. ".luau"

	local function search(directory: string): string?
		for _, entry in zune.fs.entries(directory) do
			if entry.kind == "directory" then
				local found = search(`{directory}/{entry.name}`)

				if found then
					return found
				end
			elseif entry.kind == "file" and entry.name == target and entry.name ~= "meta.luau" then
				return `{directory}/{entry.name}`
			end
		end

		return nil
	end

	return search("src/commands")
end

local pathOption = builders.interaction.option
	.new()
	:setType("String")
	:setName("path")
	:setDescription("Command name (e.g. ping) or full path (e.g. src/commands/utility/ping.luau)")
	:build()

local COMMAND_OBJECT = builders.interaction.interaction
	.new()
	:setName("command")
	:setDescription("Hot reload developer commands at runtime")
	:setType("ChatInput")
	:addIntegrationType("UserInstall")
	:addContext("Guild")
	:addContext("BotDm")
	:addContext("PrivateChannel")
	:setDefaultMemberPermissions(8)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("load")
			:setDescription("Load a command from a file path")
			:addOption(pathOption)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("unload")
			:setDescription("Unload a currently loaded command")
			:addOption(pathOption)
			:build()
	)
	:addOption(
		builders.interaction.option
			.new()
			:setType("SubCommand")
			:setName("reload")
			:setDescription("Reload a command from a file path")
			:addOption(pathOption)
			:build()
	)
	:build()

return function()
	local addToBinder, cleanup = binder()

	addToBinder(discordBot.onCommandInteraction:listen(function(interaction)
		if interaction.data.name ~= "command" then
			return
		end

		handleInteraction(interaction, { "developer" }, function()
			local subcommand = interaction.data.options[1]

			if not subcommand then
				logger:warn("Received /command interaction with no subcommand")

				reply(interaction, "No subcommand provided.")

				return
			end

			local interactionPathOption = subcommand.options and subcommand.options[1]
			local pathInput = interactionPathOption and interactionPathOption.value

			if not pathInput or pathInput == "" then
				logger:warn(`Received /{subcommand.name} with no path`)

				reply(interaction, "No path provided.")

				return
			end

			local resolvedPath = resolveCommandPath(pathInput)

			if not resolvedPath then
				logger:warn(`Could not resolve command '{pathInput}'`)

				reply(interaction, `Could not find a command matching \`{pathInput}\`.`)

				return
			end

			logger:info(`Discord invoked /{subcommand.name} for '{resolvedPath}' (input: '{pathInput}')`)

			local success, errorMessage = pcall(function()
				if subcommand.name == "load" then
					commands:loadCommand(resolvedPath)

					reply(interaction, `Loaded \`{resolvedPath}\`.`)
				elseif subcommand.name == "unload" then
					commands:unloadCommand(resolvedPath)

					reply(interaction, `Unloaded \`{resolvedPath}\`.`)
				elseif subcommand.name == "reload" then
					commands:reloadCommand(resolvedPath)

					reply(interaction, `Reloaded \`{resolvedPath}\`.`)
				else
					logger:warn(`Unknown subcommand '{subcommand.name}'`)

					reply(interaction, `Unknown subcommand \`{subcommand.name}\`.`)
				end
			end)

			if not success then
				logger:error(`/{subcommand.name} '{resolvedPath}' failed: {errorMessage}`)

				reply(interaction, `Error: {errorMessage}`)
			end
		end)
	end))

	commands:registerAsync(COMMAND_OBJECT)

	return cleanup
end
