-- https://github.com/kevinhwang91/nvim-ufo
-- 🌈 高性能代码折叠插件，支持 LSP / Treesitter / indent 等多种 provider
-- 可与自定义虚拟文本（foldtext）配合，实现更美观的折叠显示

return {
	"kevinhwang91/nvim-ufo", -- 插件主体
	event = "VeryLazy", -- 延迟加载，启动后空闲时再加载
	dependencies = { "kevinhwang91/promise-async" }, -- UFO 的异步依赖库（必须要有）

	config = function()
		-- 加载自定义的 Foldtext 模块
		local foldtext = require("utils.foldtext")

		-- =========================
		-- 🧱 基础折叠设置（推荐）
		-- =========================
		vim.o.foldcolumn = "1" -- 左侧折叠列宽度，"0" 表示隐藏，"1" 表示显示一个字符宽度
		vim.o.foldlevel = 99 -- 默认展开层级（数值越大展开越多）
		vim.o.foldlevelstart = 99 -- 打开文件时的初始展开层级
		vim.o.foldenable = true -- 启用折叠功能（false 表示禁用）

		-- =========================
		-- ⚙️ UFO 主配置
		-- =========================
		require("ufo").setup({
			-- 选择折叠 provider
			-- LSP 提供语义级折叠，indent 提供缩进折叠
			provider_selector = function(_, filetype)
				return { "lsp", "indent" }
			end,

			-- 自定义虚拟文本渲染（显示在折叠行上）
			-- 来自 utils/foldtext.lua 模块
			fold_virt_text_handler = foldtext.custom_foldtext,
		})

		-- =========================
		-- 🎹 快捷键映射
		-- =========================
		-- zR：展开所有折叠
		vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "展开所有折叠" })
		-- zM：关闭所有折叠
		vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "关闭所有折叠" })
	end,
}
