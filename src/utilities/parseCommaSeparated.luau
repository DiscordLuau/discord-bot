return function(raw: string): { string }
	local result = {}

	for item in raw:gmatch("[^,]+") do
		local trimmed = item:match("^%s*(.-)%s*$")

		if trimmed ~= "" then
			table.insert(result, trimmed)
		end
	end

	return result
end
