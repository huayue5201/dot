-- https://github.com/bassamsdata/namu.nvim/tree/main

return {
	"bassamsdata/namu.nvim",
	opts = {
		-- 全局配置
		global = {
			-- 在 pick 弹窗里是否高亮当前符号
			focus_current_symbol = true,
			-- 默认是否自动选择（当只剩一个选项时）
			auto_select = false,
			-- 打开时是否最小化：false = 默认展示所有
			initially_hidden = false,
		},

		-- 针对 namu 的各个 module 的配置
		namu_symbols = {
			enable = true,
			options = {
				-- 只显示某些 kinds（符号类型）
				AllowKinds = {
					default = {
						"Function",
						"Method",
						"Class",
						"Module",
						"Property",
						"Variable",
					},
					-- 你可以为特定语言覆盖 kinds
					go = {
						"Function",
						"Method",
						"Struct",
						"Field",
						"Interface",
						"Constant",
					},
				},

				-- 显示方式：prefix 图标 + 原始名字
				display = {
					mode = "icon", -- 可选 "icon" 或 "raw"
					padding = 2,
					format = "tree_guides",
				},

				-- 窗口位置和预览设置
				row_position = "top10", -- “top10”, “center”, 等
				preview = {
					highlight_on_move = true,
					highlight_mode = "always", -- "always" 或 "select"
				},

				window = {
					auto_size = true,
					min_height = 1,
					min_width = 20,
					max_width = 120,
					max_height = 30,
					padding = 2,
					border = "rounded",
					title_pos = "left",
					show_footer = true,
					footer_pos = "right",
					relative = "editor",
					style = "minimal",
					width_ratio = 0.6,
					height_ratio = 0.6,
					title_prefix = "󱠦 ",
				},

				debug = false,

				multiselect = {
					enabled = true,
					indicator = "✓",
					keymaps = {
						toggle = "<Tab>",
						untoggle = "<S-Tab>",
						select_all = "<C-a>",
						clear_all = "<C-l>",
					},
					max_items = nil, -- 不限制数量
				},

				actions = {
					close_on_yank = false,
					close_on_delete = true,
				},

				movement = {
					next = { "<C-n>", "<Down>" },
					previous = { "<C-p>", "<Up>" },
					close = { "<Esc>" },
					select = { "<CR>" },
					delete_word = {},
					clear_line = {},
				},

				custom_keymaps = {
					yank = {
						keys = { "<C-y>" },
					},
					delete = {
						keys = { "<C-d>" },
					},
					vertical_split = {
						keys = { "<C-v>" },
					},
					horizontal_split = {
						keys = { "<C-h>" },
					},
					-- 这里是跟 CodeCompanion 集成（可选）
					codecompanion = {
						keys = "<C-o>",
					},
				},
			},
		},

		namu_workspace = {
			enable = true,
			options = {
				-- workspace module 的具体配置（和 namu_symbols 类似结构）
			},
		},

		namu_watchtower = {
			enable = true,
			options = {
				-- 所有 buffer 的 symbols 模块
			},
		},

		namu_diagnostics = {
			enable = true,
			options = {
				-- diagnostics 过滤等设置
			},
		},

		namu_call_hierarchy = {
			enable = true,
			options = {
				-- call hierarchy in / out / both 逻辑
			},
		},

		namu_ctags = {
			enable = true,
			options = {
				-- ctags module（如果你安装了 ctags）
			},
		},
	},

	-- 建议 keymap
	config = function(_, opts)
		local namu = require("namu")

		-- 你可以在这里调用 setup
		namu.setup(opts)

		-- 常用命令映射
		vim.keymap.set("n", "<leader>ls", "<cmd>Namu symbols<cr>", { desc = "Namu: Symbols (buffer)" })
		vim.keymap.set("n", "<leader>lS", "<cmd>Namu workspace watchtower<cr>", { desc = "Namu: Workspace symbols" })
		vim.keymap.set(
			"n",
			"<leader>fd",
			"<cmd>Namu diagnostics workspace<cr>",
			{ desc = "Namu: Diagnostics workspace" }
		)
		-- 如果你启用了 ctags
		vim.keymap.set("n", "<leader>ft", "<cmd>Namu ctags watchtower<cr>", { desc = "Namu: Ctags symbols" })
	end,
}
