-- https://github.com/oskarrrrrrr/symbols.nvim

return {
	"oskarrrrrrr/symbols.nvim",
	event = "BufReadPost",
	config = function()
		local r = require("symbols.recipes")

		require("symbols").setup(r.DefaultFilters, r.AsciiSymbols, {
			sidebar = {
				-- Side on which the sidebar will open, available options:
				-- try-left  Opens to the left of the current window if there are no
				--           windows there. Otherwise opens to the right.
				-- try-right Opens to the right of the current window if there are no
				--           windows there. Otherwise opens to the left.
				-- right     Always opens to the right of the current window.
				-- left      Always opens to the left of the current window.
				open_direction = "right",
				-- custom settings here
				-- e.g. hide_cursor = false
				auto_resize = {
					-- When enabled the sidebar will be resized whenever the view changes.
					-- For example, after folding/unfolding symbols, after toggling inline details
					-- or whenever the source file is saved.
					enabled = true,
					-- The sidebar will never be auto resized to a smaller width then `min_width`.
					min_width = 32,
					-- The sidebar will never be auto resized to a larger width then `max_width`.
					max_width = 40,
				},
			},
		})
		vim.keymap.set("n", "<leader>sf", "<cmd>SymbolsToggle<CR>")
	end,
}
