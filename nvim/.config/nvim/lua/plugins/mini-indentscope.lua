-- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-indentscope.md

return {
	"nvim-mini/mini.indentscope",
	sem_version = "*",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("mini.indentscope").setup({
			symbol = "│",
		})
	end,
}
