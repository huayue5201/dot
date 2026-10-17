-- https://github.com/huayue5201/nvim-store3

return {
	dir = "~/neovim-plugins/nvim-store3",
	-- "huayue5201/nvim-store3",
	name = "nvim-store3",
	event = "VeryLazy",
	main = "nvim-store3", -- 核心修复：明确指定主模块，阻止 lazy.nvim 自动分析内部配置
	config = function()
		require("nvim-store3.plugins.project_query").setup()
		require("nvim-store3.plugins.project_delete").setup()
		vim.keymap.set("n", "<leader>mss", "<cmd>Store<CR>", { desc = "存储: 查看项目数据" })
		vim.keymap.set("n", "<leader>msd", "<cmd>StoreDelete<CR>", { desc = "存储: 删除项目数据" })
	end,
}
