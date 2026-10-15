-- https://github.com/rachartier/tiny-inline-diagnostic.nvim
-- 内联诊断显示（替代 Neovim 内置 virtual_text / virtual_lines）
-- NOTE: 必须在 LSP 侧（lua/lsp-config/diagnostics.lua）关闭内置 virtual_text/virtual_lines，
--       否则会与插件重复显示。此处只负责样式与行为；优先级 1000 保证在主题/其他插件前加载。
return {
	"rachartier/tiny-inline-diagnostic.nvim",
	event = "VeryLazy",
	priority = 1000,
	opts = {
		preset = "modern", -- modern | classic | minimal | powerline | ghost | simple | nonerdfont | amongus
		transparent_bg = false,
		transparent_cursorline = true,
		hi = {
			error = "DiagnosticError",
			warn = "DiagnosticWarn",
			info = "DiagnosticInfo",
			hint = "DiagnosticHint",
			arrow = "NonText",
			background = "CursorLine",
			mixing_color = "Normal",
		},
		options = {
			show_source = { enabled = true, if_many = true }, -- 多来源时才显示 LSP 名，减少噪音
			show_code = true,
			throttle = 20,
			softwrap = 30,
			-- 诊断数量与消息的显示方式（需配合 multilines）
			add_messages = {
				messages = true,
				display_count = false,
				use_max_severity = false,
				show_multiple_glyphs = true,
			},
			-- 多行诊断
			multilines = {
				enabled = true,
				always_show = false,
				trim_whitespaces = false,
				tabstop = 4,
			},
			show_all_diags_on_cursorline = false,
			show_related = { enabled = true, max_count = 3 },
			enable_on_insert = false,
			enable_on_select = false,
			overflow = { mode = "wrap", padding = 0 },
			break_line = { enabled = false, after = 30 },
			virt_texts = { priority = 2048 },
			severity = {
				vim.diagnostic.severity.ERROR,
				vim.diagnostic.severity.WARN,
				vim.diagnostic.severity.INFO,
				vim.diagnostic.severity.HINT,
			},
			-- 打开诊断浮窗时自动隐藏内联诊断，避免重叠
			override_open_float = true,
		},
	},
	config = function(_, opts)
		require("tiny-inline-diagnostic").setup(opts)
		-- 双保险：确保内置的内联诊断已关闭（真正的设置在 lsp-config.diagnostics）
		vim.diagnostic.config({ virtual_text = false, virtual_lines = false })
	end,
}
