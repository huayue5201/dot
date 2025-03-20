-- https://github.com/rbong/vim-flog

return {
	"rbong/vim-flog",
	keys = {
		{ "<leader>gl", desc = "Flog" },
		{ "<leader>og", desc = "Floggit" },
	},
	cmd = { "Flog", "Flogsplit", "Floggit" },
	dependencies = {
		"tpope/vim-fugitive",
	},
	config = function()
		vim.g.flog_enable_extended_chars = 1
		vim.keymap.set("n", "<leader>gl", "<cmd>Flog<cr>", { silent = true, desc = "Flog" })
		vim.keymap.set("n", "<leader>og", "<cmd>Floggit<cr>", { silent = true, desc = "Floggit" })
	end,
}
