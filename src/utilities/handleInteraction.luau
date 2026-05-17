local logger = require("../objects/logger")

local checkPermissions = require("../utilities/checkPermissions")
local logCommand = require("../utilities/logCommand")
local respondCommand = require("../utilities/respondCommand")
local truncate = require("../utilities/truncate")

return function(interaction: any, levels: { string }, fn: () -> ())
	if not checkPermissions(interaction, levels) then
		interaction:messageAsync(respondCommand("You don't have permission to use this command.")):poll()

		return
	end

	logCommand(interaction)

	local success, errorMessage = xpcall(fn, debug.traceback)

	if not success then
		local errorString = truncate(tostring(errorMessage or "unknown error"), 950)

		logger:warn(`Unhandled command error: {errorString}`)

		interaction:messageAsync(respondCommand(`An error occurred:\n\`\`\`\n{errorString}\n\`\`\``)):poll()
	end
end
