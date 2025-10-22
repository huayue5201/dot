-- https://github.com/github/copilot.vim

return {
	"github/copilot.vim",
	event = "VeryLazy",
	config = function()
		vim.keymap.set("i", "<A-j>", 'copilot#Accept("\\<CR>")', {
			expr = true,
			replace_keycodes = false,
		})
		vim.keymap.set("i", "<A-l>", "<Plug>(copilot-accept-word)")
		vim.g.copilot_no_tab_map = true
	end,
}
