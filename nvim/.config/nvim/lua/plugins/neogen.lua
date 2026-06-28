-- https://github.com/danymat/neogen
-- TODO:备选:https://github.com/jeangiraldoo/codedocs.nvim

return {
	"danymat/neogen",
	event = "VeryLazy",
	-- 如果想使用稳定版本可以取消注释
	-- version = "*"
	config = function()
		require("neogen").setup({
			-- 生成注释后自动跳转到占位符并进入插入模式
			input_after_comment = true,

			-- 启用占位符（用于填充参数、描述等）
			enable_placeholders = true,

			-- 自定义占位符文本（可选，调整为自己喜欢的风格）
			placeholders_text = {
				["description"] = "description",
				["parameter"] = "param",
				["return"] = "return value",
				["class"] = "class description",
				["type"] = "type description",
			},

			-- 占位符高亮（nil 表示使用默认）
			placeholders_hl = "Comment",

			-- 如果想使用代码片段引擎（推荐 luasnip）
			snippet_engine = "nvim",
		})

		-- 快捷键配置
		local opts = { noremap = true, silent = true }

		-- 自动检测类型（推荐）
		vim.api.nvim_set_keymap("n", "gCn", "<cmd>Neogen<CR>", opts)

		-- 或者显式指定类型
		vim.api.nvim_set_keymap("n", "gCf", "<cmd>Neogen func<CR>", opts) -- 函数注释
		vim.api.nvim_set_keymap("n", "gCc", "<cmd>Neogen class<CR>", opts) -- 类注释

		-- 如果使用 luasnip，添加跳转快捷键
		-- vim.api.nvim_set_keymap("i", "<C-j>", "<Plug>luasnip-next-choice", opts)
		-- vim.api.nvim_set_keymap("s", "<C-j>", "<Plug>luasnip-next-choice", opts)
	end,
}
