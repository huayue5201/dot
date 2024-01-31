-- https://github.com/ibhagwan/fzf-lua

return {
	"ibhagwan/fzf-lua",
	event = "VeryLazy",
	-- optional for icon support
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- calling `setup` is optional for customization
		require("fzf-lua").setup({})
		vim.keymap.set("n", "<leader>of", "<cmd>FzfLua files<cr>", { desc = "文件检索" })
		vim.keymap.set("n", "<leader>ob", "<cmd>FzfLua buffers<cr>", { desc = "buffers检索" })
		vim.keymap.set("n", "<leader>og", "<cmd>FzfLua grep<cr>", { desc = "字符检索" })
	end,
}
