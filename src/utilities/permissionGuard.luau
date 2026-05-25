local checkPermissions = require("../utilities/checkPermissions")

return function(levels: { string }): (interaction: any) -> boolean
	return function(interaction)
		return checkPermissions(interaction, levels)
	end
end
