-- https://github.com/nvim-treesitter/nvim-treesitter-context

return {
	"nvim-treesitter/nvim-treesitter-context",
	config = function()
		-- 配置 treesitter-context 插件
		require("treesitter-context").setup({
			enable = true, -- 启用此插件（以后可以通过命令启用/禁用）
			max_lines = 0, -- 窗口应跨越的最大行数。值 <= 0 表示无限制。
			min_window_height = 0, -- 启用上下文的最小编辑器窗口高度。值 <= 0 表示无限制。
			line_numbers = true, -- 是否显示行号
			multiline_threshold = 20, -- 单个上下文显示的最大行数
			trim_scope = "outer", -- 如果超过 `max_lines`，则丢弃哪些上下文行。选项: 'inner', 'outer'
			mode = "cursor", -- 用于计算上下文的行。选项: 'cursor', 'topline'
			-- 上下文和内容之间的分隔符。应该是一个单字符字符串，如 '-'。
			-- 当设置了分隔符时，只有在光标行之上至少有 2 行时，上下文才会显示出来。
			separator = nil,
			zindex = 20, -- 上下文窗口的 Z 索引
			on_attach = nil, -- (fun(buf: integer): boolean) 返回 false 以禁用附加
		})

		-- 跳转到上下文
		vim.keymap.set("n", "[c", function()
			require("treesitter-context").go_to_context(vim.v.count1)
		end, { desc = "跳转到上下文", silent = true }) -- 静默执行
	end,
}
