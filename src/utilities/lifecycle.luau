return function(modules: { any }, lifecycleName: string)
	table.sort(modules, function(moduleA, moduleB)
		return (moduleA.Priority or 0) > (moduleB.Priority or 0)
	end)

	for _, module in modules do
		if module[lifecycleName] then
			module[lifecycleName](module)
		end
	end
end
