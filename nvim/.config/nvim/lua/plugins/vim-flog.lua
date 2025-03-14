-- https://github.com/rbong/vim-flog

return {
	"rbong/vim-flog",
	lazy = true,
	cmd = { "Flog", "Flogsplit", "Floggit" },
	dependencies = {
		"tpope/vim-fugitive",
	},
}
