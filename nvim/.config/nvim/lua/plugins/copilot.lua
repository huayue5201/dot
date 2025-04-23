-- https://github.com/github/copilot.vim
-- cmd:Copilot setup

return {
	"github/copilot.vim", -- or zbirenbaum/copilot.lua
	event = "VeryLazy",
	-- lazy = true,
	config = function()
		vim.g.copilot_no_tab_map = true
		vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
			expr = true,
			replace_keycodes = false,
		})
		vim.keymap.set("i", "<C-L>", "<Plug>(copilot-accept-word)")
	end,
}
