local builders = require("../../luau_packages/builders")

local IS_COMPONENTS_V2 = 32768

return function(components: { any })
	local message = builders.message.message.new():setFlags(IS_COMPONENTS_V2)

	for _, component in components do
		message:addComponent(component)
	end

	return message:build()
end
