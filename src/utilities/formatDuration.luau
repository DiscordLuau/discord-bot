return function(seconds: number): string
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = math.floor(seconds % 60)
	local parts = {}

	if days > 0 then
		table.insert(parts, `{days}d`)
	end

	if hours > 0 then
		table.insert(parts, `{hours}h`)
	end

	if minutes > 0 then
		table.insert(parts, `{minutes}m`)
	end

	if remainingSeconds > 0 or #parts == 0 then
		table.insert(parts, `{remainingSeconds}s`)
	end

	return table.concat(parts, " ")
end
