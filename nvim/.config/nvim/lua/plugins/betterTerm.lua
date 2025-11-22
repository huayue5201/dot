-- https://github.com/CRAG666/betterTerm.nvim/tree/main
-- NOTE:https://github.com/nvzone/floaterm 浮动终端插件

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

		-- Toggle the first terminal (ID defaults to index_base, which is 0)
		vim.keymap.set({ "n", "t" }, "<C-;>", function()
			betterTerm.open()
		end, { desc = "Toggle terminal" })

		-- Open a specific terminal
		-- vim.keymap.set({ "n", "t" }, "<C-\\>", function()
		-- 	betterTerm.open(1)
		-- end, { desc = "Toggle terminal 1" })

		-- Select a terminal to focus
		vim.keymap.set("n", "<localleader>tt", betterTerm.select, { desc = "Select terminal" })

		-- Rename the current terminal
		vim.keymap.set("n", "<localleader>tr", betterTerm.rename, { desc = "Rename terminal" })

		-- Toggle the tabs bar
		vim.keymap.set("n", "<localleader>tb", betterTerm.toggle_tabs, { desc = "Toggle terminal tabs" })

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
