local logger = require("../objects/logger")

local uuid = require("../utilities/uuid")

return function(modulePath)
	local fileInformation = zune.fs.stat(modulePath)

	if fileInformation.kind ~= "file" then
		logger:warn(`Failed to hot reload file '{modulePath}' - file kind is '{fileInformation.kind}', expected 'file'`)

		return
	end

	local fileUuid = uuid()
	local newFileName = `{modulePath}.{fileUuid}.tmp.luau`

	zune.fs.copy(modulePath, newFileName)
	zune.task.defer(function()
		zune.fs.deleteFile(newFileName)
	end)

	local module = require(`../{modulePath:gsub("^src/", "")}.{fileUuid}.tmp`)

	return module
end
