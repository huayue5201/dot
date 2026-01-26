-- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-indentscope.md

return {
	"nvim-mini/mini.indentscope",
	version = "*",
	config = function()
		require("mini.indentscope").setup({
			symbol = "│",
		})
	end,
}
