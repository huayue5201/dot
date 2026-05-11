-- https://github.com/nvim-neotest/neotest

return {
	"nvim-neotest/neotest",
	event = "VeryLazy",
	dependencies = {
		"nvim-neotest/nvim-nio", -- 可选，提升异步操作体验
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"huayue5201/neotest-rust", -- Rust 测试适配器
	},
	config = function()
		local neotest = require("neotest")

		-- Neotest 完整配置
		neotest.setup({
			-- 适配器配置
			adapters = {
				require("neotest-rust")({
					-- Rust 特定配置
					dap_adapter = "codelldb", -- 使用 codelldb 进行调试（需要安装 nvim-dap 和相关配置）
					-- 可选：自定义测试二进制查找路径
					-- test_binary_target = "debug",  -- "debug" 或 "release"
				}),
			},

			-- 基准测试配置
			benchmark = {
				enabled = true,
			},

			-- 默认策略
			default_strategy = "integrated",

			-- 诊断配置
			diagnostic = {
				enabled = true,
				severity = 1, -- vim.diagnostic.severity.ERROR
			},

			-- 测试发现配置
			discovery = {
				enabled = true,
				concurrent = 0, -- 0 = 自动根据 CPU 核心数
			},

			-- 浮动窗口配置
			floating = {
				max_height = 0.6,
				max_width = 0.6,
				options = {
					winblend = 10, -- 透明度
				},
			},

			-- 图标配置
			icons = {
				passed = "✓",
				failed = "✗",
				running = "⟳",
				skipped = "⨯",
				unknown = "?",
				watching = "👁",
				child_indent = "│",
				child_prefix = "├",
				final_child_indent = " ",
				final_child_prefix = "╰",
				collapsed = "─",
				expanded = "╮",
				non_collapsible = "─",
				notify = "",
				running_animated = { "/", "|", "\\", "-", "/", "|", "\\", "-" },
			},

			-- 高亮配置
			highlights = {
				adapter_name = "NeotestAdapterName",
				border = "NeotestBorder",
				dir = "NeotestDir",
				expand_marker = "NeotestExpandMarker",
				failed = "NeotestFailed",
				file = "NeotestFile",
				focused = "NeotestFocused",
				indent = "NeotestIndent",
				marked = "NeotestMarked",
				namespace = "NeotestNamespace",
				passed = "NeotestPassed",
				running = "NeotestRunning",
				select_win = "NeotestWinSelect",
				skipped = "NeotestSkipped",
				target = "NeotestTarget",
				test = "NeotestTest",
				unknown = "NeotestUnknown",
				watching = "NeotestWatching",
			},

			-- 跳转配置
			jump = {
				enabled = true,
			},

			-- 日志级别
			log_level = 3, -- vim.log.levels.INFO

			-- 输出配置
			output = {
				enabled = true,
				open_on_run = "short", -- "short" = 只在失败时打开, true = 总是打开, false = 不打开
			},

			-- 输出面板配置
			output_panel = {
				enabled = true,
				open = "botright split | resize 15", -- 打开面板的命令
			},

			-- 项目特定配置（可选）
			projects = {},

			-- Quickfix 列表配置
			quickfix = {
				enabled = false, -- 你之前设为 false
				open = false,
			},

			-- 运行配置
			run = {
				enabled = true,
				-- 可选：自定义运行参数
				-- augment = function(tree, args)
				--   return args
				-- end,
			},

			-- 并发运行配置
			running = {
				concurrent = true, -- 并发运行测试
			},

			-- 状态配置
			state = {
				enabled = true,
			},

			-- 状态栏配置
			status = {
				enabled = true,
				signs = true, -- 显示符号标记
				virtual_text = false, -- 是否显示虚拟文本
			},

			-- 策略配置
			strategies = {
				integrated = {
					height = 40,
					width = 120,
				},
			},

			-- 总结窗口配置
			summary = {
				enabled = true,
				animated = true, -- 动画效果
				count = true, -- 显示测试数量
				expand_errors = true, -- 自动展开错误
				follow = true, -- 跟随当前文件
				open = "botright vsplit | vertical resize 50", -- 打开总结窗口的命令
				-- 总结窗口映射（覆盖默认值）
				mappings = {
					expand = { "<CR>", "<2-LeftMouse>" },
					expand_all = "e",
					output = "o",
					short = "O",
					attach = "a",
					jumpto = "i",
					stop = "u",
					run = "r",
					debug = "d",
					mark = "m",
					run_marked = "R",
					debug_marked = "D",
					clear_marked = "M",
					target = "t",
					clear_target = "T",
					next_failed = "J",
					prev_failed = "K",
					next_sibling = ">",
					prev_sibling = "<",
					parent = "P",
					watch = "w",
					help = "?",
				},
			},

			-- 监视配置
			watch = {
				enabled = true,
				-- symbol_queries 会从默认配置继承
			},
		})

		-- ======================
		-- 键位映射
		-- ======================

		local opts = { noremap = true, silent = true }

		-- 运行最近的测试
		vim.keymap.set("n", "<leader>tr", function()
			neotest.run.run()
		end, vim.tbl_extend("force", opts, { desc = "Run nearest test" }))

		-- 运行当前文件的所有测试
		vim.keymap.set("n", "<leader>tf", function()
			neotest.run.run(vim.fn.expand("%"))
		end, vim.tbl_extend("force", opts, { desc = "Run file tests" }))

		-- 运行所有测试
		vim.keymap.set("n", "<leader>ta", function()
			neotest.run.run({ suite = true })
		end, vim.tbl_extend("force", opts, { desc = "Run all tests" }))

		-- 运行上次的测试
		vim.keymap.set("n", "<leader>tl", function()
			neotest.run.run_last()
		end, vim.tbl_extend("force", opts, { desc = "Run last test" }))

		-- 运行测试并使用 DAP 调试
		vim.keymap.set("n", "<leader>td", function()
			neotest.run.run({ strategy = "dap" })
		end, vim.tbl_extend("force", opts, { desc = "Debug nearest test" }))

		-- 打开最近测试的输出
		vim.keymap.set("n", "<leader>to", function()
			neotest.output.open({ enter = true })
		end, vim.tbl_extend("force", opts, { desc = "Open test output" }))

		-- 停止运行的测试
		vim.keymap.set("n", "<leader>ts", function()
			neotest.run.stop()
		end, vim.tbl_extend("force", opts, { desc = "Stop test run" }))

		-- 打开测试总结窗口
		vim.keymap.set("n", "<leader>tt", function()
			neotest.summary.toggle()
		end, vim.tbl_extend("force", opts, { desc = "Toggle test summary" }))

		-- 跳转到下一个失败的测试
		-- vim.keymap.set("n", "]t", function()
		-- 	neotest.jump.next({ status = "failed" })
		-- end, vim.tbl_extend("force", opts, { desc = "Next failed test" }))

		-- 跳转到上一个失败的测试
		-- vim.keymap.set("n", "[t", function()
		-- 	neotest.jump.prev({ status = "failed" })
		-- end, vim.tbl_extend("force", opts, { desc = "Previous failed test" }))

		-- 跳转到最后一个测试位置
		vim.keymap.set("n", "<leader>tj", function()
			neotest.jump.last()
		end, vim.tbl_extend("force", opts, { desc = "Jump to last test" }))

		-- 切换监视模式（文件变化时自动运行测试）
		vim.keymap.set("n", "<leader>tw", function()
			neotest.watch.toggle()
		end, vim.tbl_extend("force", opts, { desc = "Toggle watch mode" }))

		-- 打开输出面板
		vim.keymap.set("n", "<leader>tp", function()
			neotest.output_panel.toggle()
		end, vim.tbl_extend("force", opts, { desc = "Toggle output panel" }))

		-- 在总结窗口中运行标记的测试
		vim.keymap.set("n", "<leader>tm", function()
			neotest.summary.run_marked()
		end, vim.tbl_extend("force", opts, { desc = "Run marked tests" }))

		-- 在 Rust 文件中快速运行特定测试（视觉模式）
		vim.keymap.set("v", "<leader>tr", function()
			neotest.run.run()
		end, vim.tbl_extend("force", opts, { desc = "Run selected test" }))
	end,
}
