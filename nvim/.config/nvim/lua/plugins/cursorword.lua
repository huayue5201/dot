-- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-cursorword.md

return {
	"nvim-mini/mini.cursorword",
	event = "VeryLazy",
	config = function()
		require("mini.cursorword").setup()
	end,
}
