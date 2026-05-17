local config = require("../config")
local logger = require("../objects/logger")

return function(interaction: any, levels: { string }): boolean
	if #levels == 0 then
		return true
	end

	local userId = interaction.user and interaction.user.id
		or interaction.member and interaction.member.user and interaction.member.user.id

	local memberRoles: { string } = interaction.member and interaction.member.roles or {}

	for _, level in levels do
		local permissionConfig = config.permissions[level]

		if not permissionConfig then
			logger:warn(`Unknown permission level '{level}'`)

			continue
		end

		for _, allowedUserId in permissionConfig.userIds do
			if userId == allowedUserId then
				return true
			end
		end

		for _, allowedRoleId in permissionConfig.roleIds do
			for _, memberRoleId in memberRoles do
				if memberRoleId == allowedRoleId then
					return true
				end
			end
		end
	end

	return false
end
