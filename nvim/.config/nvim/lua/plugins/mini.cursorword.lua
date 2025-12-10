-- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-cursorword.md

return {
	"nvim-mini/mini.cursorword",
	version = "*",
	config = function()
		require("mini.cursorword").setup({
			delay = 200,
		})
	end,
}
