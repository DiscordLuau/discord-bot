local commandsPackage = require("../../luau_packages/commands")

local discordBot = require("../objects/discordBot")
local logger = require("../objects/logger")

local logCommand = require("../utilities/logCommand")
local respondCommand = require("../utilities/respondCommand")
local truncate = require("../utilities/truncate")

local commands = commandsPackage.new(discordBot, {
	help = true,
	watch = true,
	onError = function(interaction, errorMessage)
		local errorString = truncate(tostring(errorMessage), 950)

		logger:warn(`Unhandled command error: {errorString}`)

		interaction:messageAsync(respondCommand(`An error occurred:\n\`\`\`\n{errorString}\n\`\`\``, true)):poll()
	end,
	onGuardFailed = function(interaction)
		interaction:messageAsync(respondCommand("You don't have permission to use this command.", true)):poll()
	end,
})

commands:after(logCommand)

return commands
