return function()
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"

	return string.gsub(template, "[xy]", function(character)
		local value = (character == "x") and math.random(0, 0xf) or math.random(8, 0xb)

		return string.format("%x", value)
	end)
end
