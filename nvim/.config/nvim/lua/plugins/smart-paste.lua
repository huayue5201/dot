-- https://github.com/nemanjamalesija/smart-paste.nvim
-- 行级粘贴自动对齐当前缩进（取代 boot/keymaps.lua 里 `p` -> "p`[v`]=" 的粗糙版）。
-- 三层缩进策略：indentexpr -> treesitter 作用域分析 -> 启发式兜底。
-- 接管：p / P / gp / gP（仅行级寄存器）、]p / [p（字符级寄存器变成正确缩进的整行）、
-- 可视模式 V + p/P（用寄存器内容替换选中行并重新缩进）。字符级/块级 p 保持原生。
-- 逃生通道：<Plug>(smart-paste-raw-p) / <Plug>(smart-paste-raw-P)。
-- 与 yanky 不冲突：yanky 只用 <leader>p/<leader>P 和 ]y/[y，不接管 p/P/]p/[p。
-- 与 boot/keymaps.lua 不冲突的前提：那里已删掉 p 的旧映射（映射在 setup() 时注册，
-- 而 boot.keymaps 在 boot.pack 之后执行，后来者会覆盖）。

return {
	"nemanjamalesija/smart-paste.nvim",
	config = function()
		require("smart-paste").setup({
			-- 这些 filetype 跳过智能缩进，走原生粘贴
			exclude_filetypes = {
				"snacks_picker_input",
				"neo-tree",
				"qf",
				"help",
				"TelescopePrompt",
				"gitcommit",
			},
		})
	end,
}
