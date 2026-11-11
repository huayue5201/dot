-- https://github.com/petertriho/nvim-scrollbar
-- 窗口右边缘的滚动条：handle 指示当前位置，刻度标出诊断与 git hunk。
--
-- 它用 right_align 虚拟文本画在真实 buffer 上（不是独立窗口），所以不会占宽度、
-- 也不会影响 <C-w> 窗口跳转；代价是最后几列会被 handle 覆盖，行尾太长的代码
-- 靠 wrap 看没关系，不 wrap 时按 g$ 到底可能被压住一个字符。
--
-- 固定 v1 分支有原因：上游 2026-11-16 把 v2 推到 main，v2 删掉了
-- scrollbar.handlers.* 模块、改了 setup() 的选项名，还要求 nvim 0.11+。
-- v1 分支与 v1.0.0 tag 是同一个 commit，且不含那个「你的配置将来会坏」的警告。
return {
	"petertriho/nvim-scrollbar",
	branch = "v1",
	config = function()
		require("scrollbar").setup({
			-- 所有分屏都画，不只是当前窗口
			show_in_active_only = false,
			-- 整屏就能看完的文件不画（短文件右边缘保持干净）
			hide_if_all_visible = true,
			-- 行数 <= 1000 时才计算 fold，让滚动条位置和折叠后的实际行一致
			folds = 1000,
			-- 拖动条：主题的 CursorColumn 色 + 30% 透明，太亮会抢注意力
			handle = {
				text = " ",
				blend = 30,
				highlight = "CursorColumn",
				hide_if_all_visible = true,
			},
			-- nofile：浮窗 / 选择器 / help / gitsigns blame 之类的临时 buffer
			excluded_buftypes = { "terminal", "nofile", "quickfix", "prompt" },
			-- 默认排除项 + 本配置自己的界面 buffer
			excluded_filetypes = {
				"blink-cmp-menu",
				"dropbar_menu",
				"dropbar_menu_fzf",
				"DressingInput",
				"cmp_docs",
				"cmp_menu",
				"noice",
				"prompt",
				"TelescopePrompt",
				"ui-menu",
				"lazy",
				"mason",
				"OverseerList",
				"snacks_picker_list",
				"snacks_picker_input",
			},
			handlers = {
				cursor = true,
				diagnostic = true,
				-- gitsigns 已装：滚动条上显示 add/change/delete 的刻度
				gitsigns = true,
				handle = true,
				-- search 需要 nvim-hlslens，本配置没装
				search = false,
			},
		})
	end,
}
