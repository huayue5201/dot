-- https://chatgpt.com/c/691e7a4d-bab4-8327-a4c7-3908d77a92f3

return {
	"folke/todo-comments.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		signs = true, -- 显示 sign 栏的图标
		sign_priority = 8,
		keywords = {
			FIX = {
				icon = " ",
				color = "error",
				alt = { "FIXME", "BUG", "FIXIT", "ISSUE" },
			},
			TODO = { icon = " ", color = "info" },
			HACK = { icon = " ", color = "warning" },
			WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
			PERF = { icon = " ", color = "default", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
			NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
			TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
			-- 你也可以加自己的关键词
			CUSTOM = {
				icon = " ",
				color = "default",
				alt = { "CUSTOMTAG" },
			},
		},
		merge_keywords = true, -- 是否把你定义的关键词和默认关键词合并
		gui_style = {
			fg = "NONE",
			bg = "BOLD",
		},
		highlight = {
			multiline = true,
			multiline_pattern = "^.",
			multiline_context = 10,
			before = "", -- “fg” 或 “bg” 或 空
			keyword = "wide", -- “fg”, “bg”, “wide”, “wide_bg”, “wide_fg” or 空
			after = "fg", -- “fg” 或 “bg” 或 空
			pattern = [[.*<(KEYWORDS)\s*:]], -- 用于匹配 TODO 注释的 pattern（vim regex）
			comments_only = true, -- 只 highlight 注释里的关键词（通过 treesitter）
			max_line_len = 400, -- 忽略过长的行
			exclude = {}, -- 要排除高亮的 ft 列表
		},
		colors = {
			error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
			warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
			info = { "DiagnosticInfo", "#2563EB" },
			hint = { "DiagnosticHint", "#10B981" },
			default = { "Identifier", "#7C3AED" },
			test = { "Identifier", "#FF00FF" },
			-- 如果定义了 “CUSTOM” 关键词，可以定义它的颜色
			custom = "#FFD700",
		},
		search = {
			command = "rg",
			args = {
				"--color=never",
				"--no-heading",
				"--with-filename",
				"--line-number",
				"--column",
			},
			pattern = [[\b(KEYWORDS):]], -- 搜索 TODO 的正则 (rg 用)
		},
	},

	config = function(_, opts)
		require("todo-comments").setup(opts)

		-- 绑定快捷键
		vim.keymap.set("n", "]t", function()
			require("todo-comments").jump_next()
		end, { desc = "下一个 todo 注释" })
		vim.keymap.set("n", "[t", function()
			require("todo-comments").jump_prev()
		end, { desc = "上一个 todo 注释" })

		-- Telescope （如果你用了 telescope）
		vim.keymap.set("n", "<leader>st", "<cmd>TodoLocList<cr>", { desc = "在 Telescope 中查找 todos" })

		-- Trouble （如果你用了 trouble.nvim）
		vim.keymap.set("n", "<leader>xt", "<cmd>TodoTrouble<cr>", { desc = "在 Trouble 中显示 todos" })
		vim.keymap.set(
			"n",
			"<leader>xT",
			"<cmd>TodoTrouble keywords=TODO,FIX<cr>",
			{ desc = "只看 TODO / FIX (Trouble)" }
		)
	end,
}
