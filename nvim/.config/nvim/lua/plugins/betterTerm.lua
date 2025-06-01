-- https://github.com/CRAG666/betterTerm.nvim/tree/main

return {
	"CRAG666/betterTerm.nvim",
	event = "VeryLazy",
	config = function()
		local betterTerm = require("betterTerm")

		betterTerm.setup({
			position = "bot",
			size = 18,
			jump_tab_mapping = "<A-$tab>",
			new_tab_hl = "Normal",
			new_tab_icon = " ",
		})

		-- toggle firts term
		vim.keymap.set({ "n", "t" }, "<C-\\>", betterTerm.open, { desc = "Open terminal" })
		-- Select term focus
		vim.keymap.set({ "n", "t" }, "<A-\\>", betterTerm.select, { desc = "Select terminal" })

		function _G.set_terminal_keymaps()
			local opts = { buffer = 0 }
			vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
			vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
			vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
			vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
			vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
			vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
		end
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "better_term",
			callback = function()
				set_terminal_keymaps()
			end,
		})
	end,
}
