vim.ui.select = function(items, opts, on_choice)
	local choices = {}
	local format_item = opts.format_item or tostring

	-- Format the items into choices
	for i, item in ipairs(items) do
		table.insert(choices, i .. ". " .. format_item(item))
	end

	-- Ensure fzf is available and run with options
	if vim.fn.exists("*fzf#run") == 1 then
		vim.fn["fzf#run"]({
			source = choices,
			sink = function(selected)
				if selected and selected ~= "" then
					local index = tonumber(selected:match("^(%d+)"))
					if index then
						on_choice(items[index], index)
					else
						vim.notify("Invalid selection", vim.log.levels.ERROR)
					end
				else
					vim.notify("No selection made", vim.log.levels.WARN)
				end
			end,
		})
	else
		vim.notify("fzf#run is not available!", vim.log.levels.ERROR)
	end
end
