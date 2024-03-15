-- https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-files.md

return {
	"echasnovski/mini.files",
	keys = { "<leader>ef", desc = "文件树" },
	config = function()
		require("mini.files").setup({})
		vim.keymap.set("n", "<leader>ef", "<cmd>lua MiniFiles.open()<cr>", { desc = "文件树" })
	end,
}
