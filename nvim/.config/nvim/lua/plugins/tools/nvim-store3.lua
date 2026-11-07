-- https://github.com/huayue5201/nvim-store3

return {
	dir = "~/neovim-plugins/nvim-store3",
	-- "huayue5201/nvim-store3",
	name = "nvim-store3",
	main = "nvim-store3", -- 明确主模块：避免按仓库名推断到同名的内部模块
	config = function()
		require("nvim-store3.plugins.project_query").setup()
		require("nvim-store3.plugins.project_delete").setup()
		vim.keymap.set("n", "<leader>zs", "<cmd>Store<CR>", { desc = "存储: 查看项目数据" })
		vim.keymap.set("n", "<leader>zd", "<cmd>StoreDelete<CR>", { desc = "存储: 删除项目数据" })
	end,
}
