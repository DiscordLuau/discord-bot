return function(text: string, maxLength: number, suffix: string?): string
	if #text <= maxLength then
		return text
	end

	return text:sub(1, maxLength) .. (suffix or "...")
end
