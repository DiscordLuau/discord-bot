return function()
	local listeners = {}

	return function(listener)
		table.insert(listeners, listener)
	end, function()
		for _, listener in listeners do
			if typeof(listener) == "function" then
				listener()
			end
		end
	end
end
