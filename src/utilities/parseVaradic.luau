return function(...): string
	local source = ""

	for index, object in { ... } do
		source ..= `{index ~= 1 and ", " or ""}{tostring(object)}`
	end

	return source
end
