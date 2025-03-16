-- https://github.com/rbong/vim-flog

return {
	"rbong/vim-flog",
	event = "BufReadPost",
	cmd = { "Flog", "Flogsplit", "Floggit" },
	dependencies = {
		"tpope/vim-fugitive",
	},
	config = function()
		vim.g.flog_enable_extended_chars = 1
	end,
}
