-- https://github.com/joryeugene/dadbod-grip.nvim?tab=readme-ov-file

return {
	"joryeugene/dadbod-grip.nvim",
	version = "*",
	event = "VeryLazy",
	config = function()
		-- 可选：配置插件选项
		require("dadbod-grip").setup({
			-- 在这里添加 dadbod-grip 的配置选项
			-- 例如：
			-- default_connections = {
			--     ["local"] = "postgresql://localhost/mydb",
			-- },
		})

		-- 数据库连接
		vim.keymap.set("n", "<leader>sb", "<cmd>GripConnect<cr>", {
			desc = "数据库连接",
			silent = true,
			noremap = true,
		})

		-- 数据网格
		vim.keymap.set("n", "<leader>sg", "<cmd>Grip<cr>", {
			desc = "数据网格",
			silent = true,
			noremap = true,
		})

		-- 数据表
		vim.keymap.set("n", "<leader>st", "<cmd>GripTables<cr>", {
			desc = "数据表",
			silent = true,
			noremap = true,
		})

		-- 查询面板
		vim.keymap.set("n", "<leader>sq", "<cmd>GripQuery<cr>", {
			desc = "查询面板",
			silent = true,
			noremap = true,
		})

		-- 数据库结构
		vim.keymap.set("n", "<leader>ss", "<cmd>GripSchema<cr>", {
			desc = "数据库结构",
			silent = true,
			noremap = true,
		})

		-- 历史记录
		vim.keymap.set("n", "<leader>sh", "<cmd>GripHistory<cr>", {
			desc = "历史记录",
			silent = true,
			noremap = true,
		})
	end,
}
