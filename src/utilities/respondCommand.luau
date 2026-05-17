local builders = require("../../luau_packages/builders")

local EPHEMERAL = 64

return function(content: string)
	return builders.message.message.new():setContent(content):setFlags(EPHEMERAL):build()
end
