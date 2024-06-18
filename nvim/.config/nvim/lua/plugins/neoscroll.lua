-- https://github.com/karb94/neoscroll.nvim

return {
	"karb94/neoscroll.nvim",
	event = "BufReadPost",
	config = function()
		require("neoscroll").setup({})
	end,
}
