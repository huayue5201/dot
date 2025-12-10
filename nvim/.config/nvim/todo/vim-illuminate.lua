-- https://github.com/RRethy/vim-illuminate

return {
	"RRethy/vim-illuminate",
	event = "VeryLazy",
	cnofig = function()
		require("illuminate").configure({
			-- provider 表示引用来源的优先级，按顺序尝试：
			-- 1. LSP (语义引用，最准确)
			-- 2. treesitter
			-- 3. 正则匹配（最基础的 fallback）
			providers = {
				"lsp",
				"treesitter",
				"regex",
			},

			-- 高亮的延迟（毫秒）。光标停留多少时间后开始高亮。
			delay = 200,

			-- 是否高亮光标下的单词本身
			under_cursor = true,

			-- 出现次数少于多少次时不高亮（避免噪音）
			-- min_count_to_highlight = 1,

			-- 大文件优化：如果文件行数超过此值，则应用 `large_file_overrides`
			large_file_cutoff = 10000,

			-- 大文件的配置覆盖（减少性能压力）
			large_file_overrides = {
				providers = { "regex" }, -- 大文件情况下只用最轻量的正则方式
			},

			-- 禁用某些文件类型的高亮（例如 markdown 中可能影响可读性）
			filetypes_denylist = {
				"NvimTree",
				"gitcommit",
				"gitgraph",
			},

			-- 如果只想启用特定文件类型，可以用 allowlist（优先级高于 denylist）
			-- filetypes_allowlist = {},

			-- 如果开启，插件不会绑定默认按键（<A-n>, <A-p>, <A-i>）
			-- 如果你自己要映射跳转键，可以设为 true
			disable_keymaps = false,
		})

		-- 默认高亮组，用于没有指定 'kind' 的引用
		vim.api.nvim_set_hl(0, "IlluminatedWordText", { gui = "underline", cterm = "underline" })
		-- 用于标识 'read' 类型引用的高亮组
		vim.api.nvim_set_hl(0, "IlluminatedWordRead", { gui = "underline", cterm = "underline" })
		-- 用于标识 'write' 类型引用的高亮组
		vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { gui = "underline", cterm = "underline" })
	end,
}
