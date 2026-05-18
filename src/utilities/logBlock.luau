local logSink = require("../singletons/logSink")

return function(options: logSink.QueryOptions?, maxLength: number?): string
	local messages = logSink:query(options or {})
	local limit = maxLength or 1500

	if #messages == 0 then
		return "```\nNo logs captured.\n```"
	end

	local block = "```ansi\n" .. table.concat(messages, "\n") .. "\n```"

	while #block > limit and #messages > 1 do
		table.remove(messages, 1)

		block = "```ansi\n" .. table.concat(messages, "\n") .. "\n```"
	end

	return block
end
