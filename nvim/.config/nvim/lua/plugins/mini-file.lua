-- https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-files.md

return {
	"echasnovski/mini.files",
	version = "*",
	keys = {
		{ "<leader>oe", "<cmd>lua MiniFiles.open()<CR>", desc = "文件管理器" },
	},
	config = function()
		require("mini.files").setup({})
	end,
}
