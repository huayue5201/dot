-- https://github.com/andrewferrier/debugprint.nvim

return {
	"andrewferrier/debugprint.nvim",
	lazy = false, -- 必须 false，确保行高亮在首次使用前生效
	opts = {
		-- ========== 显示选项 ==========
		move_to_debugline = false, -- 插入后不移动光标（保持当前位置）
		display_location = true, -- 显示文件名和行号
		display_counter = true, -- 显示递增计数器（跨会话持久）
		display_snippet = true, -- 显示代码片段上下文（仅普通调试）
		display_timestamp = false, -- 不显示时间戳（需要时可开启）
		notify_for_registers = true, -- 寄存器操作显示通知

		-- ========== 标识符 ==========
		print_tag = "DEBUGPRINT", -- 调试语句唯一标识（用于删除/注释）

		-- ========== 行高亮（无需 mini.nvim） ==========
		highlight_lines = function()
			-- 简单的正则匹配高亮，不依赖任何插件
			return true
		end,

		-- ========== 快捷键配置 ==========
		keymaps = {
			normal = {
				-- 核心调试映射（保持默认）
				plain_below = "g?p", -- 下方普通调试
				plain_above = "g?P", -- 上方普通调试
				variable_below = "g?v", -- 下方变量调试
				variable_above = "g?V", -- 上方变量调试
				surround_plain = "g?sp", -- 上下包围普通调试
				surround_variable = "g?sv", -- 上下包围变量调试
				textobj_below = "g?o", -- 操作符模式（下方）
				textobj_above = "g?O", -- 操作符模式（上方）
				textobj_surround = "g?so", -- 操作符模式（包围）

				-- 辅助管理映射（手动添加）
				-- 注意：这些需要通过下面的 config 函数单独添加
			},
			insert = {
				plain = "<C-G>p", -- 插入模式普通调试
				variable = "<C-G>v", -- 插入模式变量调试
			},
			visual = {
				variable_below = "g?v", -- 可视模式变量调试（下方）
				variable_above = "g?V", -- 可视模式变量调试（上方）
			},
		},
	},
	config = function(_, opts)
		-- 1. 初始化插件
		require("debugprint").setup(opts)

		-- 2. 设置高亮颜色
		vim.api.nvim_set_hl(0, "DebugPrintHighlight", { fg = "#ff6600", bold = true })

		-- 3. 自动高亮包含 DEBUGPRINT 的行（简单实现）
		-- vim.api.nvim_create_autocmd("BufWritePost", {
		-- 	pattern = "*",
		-- 	callback = function()
		-- 		local bufnr = vim.api.nvim_get_current_buf()
		-- 		vim.api.nvim_buf_clear_namespace(bufnr, -1, 0, -1)
		-- 		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		-- 		for i, line in ipairs(lines) do
		-- 			if line:match("DEBUGPRINT") then
		-- 				vim.api.nvim_buf_add_highlight(bufnr, -1, "DebugPrintHighlight", i - 1, 0, -1)
		-- 			end
		-- 		end
		-- 	end,
		-- })

		-- 4. 添加辅助管理快捷键（全部以 g? 开头）
		local map = vim.keymap.set

		-- 删除所有调试行
		map("n", "g?x", ":Debugprint delete<CR>", { noremap = true, desc = "调试：删除所有 DEBUGPRINT 行" })

		-- 切换注释所有调试行
		map(
			"n",
			"g?c",
			":Debugprint commenttoggle<CR>",
			{ noremap = true, desc = "调试：切换注释所有 DEBUGPRINT 行" }
		)

		-- 重置计数器
		map("n", "g?r", ":Debugprint resetcounter<CR>", { noremap = true, desc = "调试：重置计数器" })

		-- 搜索调试行并填充 quickfix（需要 telescope/fzf-lua）
		-- 如果不使用 picker，可以注释掉这行
		-- map("n", "g?q", ":Debugprint qflist<CR>",
		--   { noremap = true, desc = "调试：调试行 → QuickFix" })

		-- 可选：快速打开/关闭调试行显示（非必要）
		-- map("n", "g?h", function()
		--   vim.api.nvim_set_hl(0, "DebugPrintHighlight", { fg = "#ff6600", bold = true })
		-- end, { desc = "调试：高亮调试行" })
	end,
}
