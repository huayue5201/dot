-- https://github.com/esmuellert/codediff.nvim
-- NOTE: 备选插件 https://github.com/CoreyKaylor/diffbandit.nvim

return {
	"esmuellert/codediff.nvim",
	event = "VeryLazy",
	cmd = "CodeDiff",
	config = function()
		require("codediff").setup({
			-- 资源管理器面板配置
			explorer = {
				position = "bottom", -- "left" 或 "bottom"
				width = 40, -- 左侧布局宽度
				height = 15, -- 底部布局高度
				hidden = false, -- 是否显示隐藏文件
			},
			-- 历史面板配置
			history = {
				position = "bottom", -- "left" 或 "bottom"
				width = 40,
				height = 15,
				initial_focus = "history",
				view_mode = "list",
			},
		})

		-- 快捷键
		local keymap = vim.keymap.set
		local opts = { noremap = true, silent = true }

		keymap(
			"n",
			"<leader>hf",
			"<cmd>CodeDiff<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: Git diff explorer" })
		)
		keymap(
			"n",
			"<leader>hh",
			"<cmd>CodeDiff history<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: Repository history" })
		)
		keymap(
			"n",
			"<leader>hd",
			"<cmd>CodeDiff file HEAD<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: Diff current file with HEAD" })
		)
		keymap(
			"n",
			"<leader>hH",
			"<cmd>CodeDiff history %<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: History of current file" })
		)
		keymap(
			"v",
			"<leader>hh",
			"<cmd>CodeDiff history<cr>",
			vim.tbl_extend("force", opts, { desc = "CodeDiff: Line range history" })
		)
	end,
}
