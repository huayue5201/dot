-- https://github.com/oskarrrrrrr/symbols.nvim/tree/main

return {
	"oskarrrrrrr/symbols.nvim",
	event = "BufReadPost",
	config = function()
		local r = require("symbols.recipes")
		require("symbols").setup(r.DefaultFilters, r.AsciiSymbols, {
			sidebar = {
				-- custom settings here
				-- e.g. hide_cursor = false
				open_direction = "right",
				auto_resize = {
					-- When enabled the sidebar will be resized whenever the view changes.
					-- For example, after folding/unfolding symbols, after toggling inline details
					-- or whenever the source file is saved.
					enabled = true,
					-- The sidebar will never be auto resized to a smaller width then `min_width`.
					min_width = 40,
					-- The sidebar will never be auto resized to a larger width then `max_width`.
					max_width = 40,
				},
			},
		})
		vim.keymap.set("n", "<leader>ls", "<cmd>SymbolsToggle<CR>")
	end,
}
