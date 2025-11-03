return {
	"benlubas/molten-nvim", -- 插件名称
	build = ":UpdateRemotePlugins", -- 安装后执行命令更新远程插件注册（Python remote plugin 必须）
	ft = { "python" }, -- 仅在 Python 文件中加载插件
	dependencies = { "3rd/image.nvim" }, -- 插件依赖 image.nvim（用于显示图片）
	init = function()
		-- 以下是一些可选配置示例，不是默认值
		vim.g.molten_image_provider = "image.nvim" -- 设置图片渲染提供器为 image.nvim
		vim.g.molten_output_win_max_height = 20 -- 输出窗口最大高度为 20 行
	end,
	config = function()
		-- 设置快捷键
		vim.keymap.set("n", "<leader>mi", ":MoltenInit<CR>", { silent = true, desc = "初始化插件" })
		vim.keymap.set(
			"n",
			"<leader>me",
			":MoltenEvaluateOperator<CR>",
			{ silent = true, desc = "运行操作符选择" }
		)
		vim.keymap.set("n", "<leader>ml", ":MoltenEvaluateLine<CR>", { silent = true, desc = "执行当前行" })
		vim.keymap.set(
			"n",
			"<leader>mt",
			":MoltenReevaluateCell<CR>",
			{ silent = true, desc = "重新执行单元格" }
		)
		vim.keymap.set(
			"v",
			"<leader>mv",
			":<C-u>MoltenEvaluateVisual<CR>gv",
			{ silent = true, desc = "执行可视化选择" }
		)
		vim.keymap.set("n", "<leader>md", ":MoltenDelete<CR>", { silent = true, desc = "删除单元格" })
		vim.keymap.set("n", "<leader>mh", ":MoltenHideOutput<CR>", { silent = true, desc = "隐藏输出窗口" })
		vim.keymap.set(
			"n",
			"<leader>ms",
			":noautocmd MoltenEnterOutput<CR>",
			{ silent = true, desc = "显示/进入输出窗口" }
		)
	end,
}
