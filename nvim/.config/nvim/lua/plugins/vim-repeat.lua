-- https://github.com/tpope/vim-repeat

return {
	"tpope/vim-repeat",
	event = "BufWinEnter",
	config = function()
		-- Enable repeat for vim-commentary
		vim.g["commentary_no_default_mappings"] = 1
	end,
}
