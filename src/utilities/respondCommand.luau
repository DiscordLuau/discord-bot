local builders = require("../../luau_packages/builders")

local EPHEMERAL = 64

return function(content: string, ephemeral: boolean?)
	local message = builders.message.message.new():setContent(content)

	if ephemeral then
		message:setFlags(EPHEMERAL)
	end

	return message:build()
end
