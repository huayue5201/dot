-- https://github.com/j-hui/fidget.nvim

return {
	"j-hui/fidget.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("fidget").setup({})
	end,
}
