-- https://github.com/bloznelis/before.nvim

return {
	"bloznelis/before.nvim",
	event = "BufReadPost",
	keys = {
		{ "<leader>o", desc = "历史编辑位置跳转(上)" },
		{ "<leader>i", desc = "历史编辑位置跳转(下)" },
		{ "<leader>qi", desc = "历史编辑列表" },
	},
	config = function()
		local before = require("before")
		before.setup()
		vim.keymap.set("n", "<leader>o", before.jump_to_last_edit, {})
		vim.keymap.set("n", "<leader>i", before.jump_to_next_edit, {})
		vim.keymap.set("n", "<leader>qo", before.show_edits_in_quickfix, {})
	end,
}
