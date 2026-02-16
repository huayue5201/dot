return {
	dir = "~/nvim-store3",
	name = "nvim-store3",
	main = "nvim-store3", -- 核心修复：明确指定主模块，阻止 lazy.nvim 自动分析内部配置
	config = function()
		require("nvim-store3.plugins.project_query").setup()
		require("nvim-store3.plugins.project_delete").setup()
		vim.keymap.set("n", "<leader>sj", "<cmd>Store<CR>", { desc = "查看项目数据" })
		vim.keymap.set("n", "<leader>rj", "<cmd>StoreDelete<CR>", { desc = "删除项目数据" })
	end,
}
