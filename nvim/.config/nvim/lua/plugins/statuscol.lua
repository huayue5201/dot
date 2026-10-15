-- https://github.com/luukvbaal/statuscol.nvim
--
-- 用 statuscol.nvim 接管 'statuscolumn'，给 git / 诊断 / DAP / 书签各分配一个
-- 固定列。原生 sign 列是「按 priority 从左到右紧凑排列，优先级低的图标在
-- 高优先级图标缺席时会左移」，无法为每类图标保留固定槽位；本插件按
-- name/namespace 把 sign 分到独立 segment，逻辑上等价于每类图标独占列。
--
-- 注意：0.13 起 sign 用 extmark（type='sign'）承载，插件的 sign 匹配也是读
-- extmark；gitsigns / 诊断 走 namespace 匹配，DAP / marks 是原生 sign 走 name 匹配。
return {
	"luukvbaal/statuscol.nvim",
	lazy = false, -- statuscolumn 需要尽早生效
	config = function()
		local builtin = require("statuscol.builtin")
		require("statuscol").setup({
			setopt = true, -- 由插件设置 'statuscolumn'
			-- 每行同类 sign 只显示 1 个；colwidth = 1，配合插件「去掉图标内空白」
			-- 的行为（sign_text:gsub('%s','')），像 " " 这种带尾随空格的图标
			-- 不会被撑成两格，列宽才稳定。
			segments = {
				-- 诊断（命名空间 nvim.vim.diagnostic.signs）
				{ sign = { namespace = { "diagnostic" }, colwidth = 1, maxwidth = 1 }, click = "v:lua.ScSa" },
				-- DAP 断点（原生 sign，名字 Dap*）
				{ sign = { name = { "Dap" }, colwidth = 1, maxwidth = 1 }, click = "v:lua.ScSa" },
				-- marks.nvim（原生 sign，名字 Marks_*）
				{ sign = { name = { "Marks_" }, colwidth = 1, maxwidth = 1 }, click = "v:lua.ScSa" },
				-- 行号（沿用内置实现，遵循 number/relativenumber）
				{
					text = { builtin.lnumfunc, " " },
					condition = { true, builtin.not_empty },
					click = "v:lua.ScLa",
				},
				-- git（gitsigns 的 extmark 命名空间为 gitsigns_signs_*）
				{ sign = { namespace = { "gitsigns" }, colwidth = 1, maxwidth = 1 }, click = "v:lua.ScSa" },
				-- 折叠列放在最后，紧贴代码（还原旧 statuscolumn 的 "%s%=%l%=%C " 布局）
				{ text = { " %C " }, click = "v:lua.ScFa" },
			},
			-- clickhandlers 用内置默认即可：
			--   gitsigns   左键预览 hunk
			--   diagnostic 左键打开浮窗
			--   Dap*       左键切换断点
		})
	end,
}
