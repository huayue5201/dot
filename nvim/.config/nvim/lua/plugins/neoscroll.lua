-- https://github.com/karb94/neoscroll.nvim

return {
	"karb94/neoscroll.nvim",
	event = "BufReadPre",
	config = function()
		require("neoscroll").setup({})
	end,
}
