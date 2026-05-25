-- https://codeberg.org/mraspaud/lsp-refactor.nvim

return {
	"lsp-refactor.nvim",
	url = "https://codeberg.org/mraspaud/lsp-refactor.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-lua/plenary.nvim",
	},
	config = function()
		-- 该插件默认不绑定任何快捷键，需要手动映射

		-- 普通模式下的重构操作
		vim.keymap.set("n", "<leader>rmf", "<cmd>LSPRefactor move_function<cr>", { desc = "Refactor: 移动函数" })
		vim.keymap.set("n", "<leader>rmc", "<cmd>LSPRefactor move_class<cr>", { desc = "Refactor: 移动类" })
		vim.keymap.set("n", "<leader>rmm", "<cmd>LSPRefactor move_method<cr>", { desc = "Refactor: 移动方法" })
		vim.keymap.set(
			"n",
			"<leader>rcd",
			"<cmd>LSPRefactor change_function_declaration<cr>",
			{ desc = "Refactor: 修改函数声明" }
		)
		vim.keymap.set(
			"n",
			"<leader>rcg",
			"<cmd>LSPRefactor replace_with_guard_clause<cr>",
			{ desc = "Refactor: 替换为卫语句" }
		)
		vim.keymap.set(
			"n",
			"<leader>rcc",
			"<cmd>LSPRefactor consolidate_conditional<cr>",
			{ desc = "Refactor: 合并条件表达式" }
		)
		vim.keymap.set(
			"n",
			"<leader>rdc",
			"<cmd>LSPRefactor decompose_conditional<cr>",
			{ desc = "Refactor: 分解条件表达式" }
		)
		vim.keymap.set(
			"n",
			"<leader>rpq",
			"<cmd>LSPRefactor replace_parameter_with_query<cr>",
			{ desc = "Refactor: 用查询替换参数" }
		)
		vim.keymap.set("n", "<leader>rif", "<cmd>LSPRefactor inline_function<cr>", { desc = "Refactor: 内联函数" })
		vim.keymap.set("n", "<leader>riv", "<cmd>LSPRefactor inline_variable<cr>", { desc = "Refactor: 内联变量" })

		-- 可视模式下的重构操作（对选中文本生效）
		vim.keymap.set("v", "<leader>ref", "<cmd>LSPRefactor extract_function<cr>", { desc = "Refactor: 提取函数" })
		vim.keymap.set("v", "<leader>rev", "<cmd>LSPRefactor extract_variable<cr>", { desc = "Refactor: 提取变量" })
		vim.keymap.set(
			"v",
			"<leader>rms",
			"<cmd>LSPRefactor move_statements_into_function<cr>",
			{ desc = "Refactor: 将语句移入函数" }
		)
		vim.keymap.set(
			"v",
			"<leader>rmC",
			"<cmd>LSPRefactor move_statements_to_callers<cr>",
			{ desc = "Refactor: 将语句移至调用方" }
		)

		-- 可选：配置 extract_function 的放置位置（默认："below"）
		-- require("lsp-refactor.extract_function").setup({ placement = "above" })
	end,
}
