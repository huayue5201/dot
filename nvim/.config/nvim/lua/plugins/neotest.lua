-- https://github.com/nvim-neotest/neotest

return {
	"nvim-neotest/neotest",
	event = "BufReadPost",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		{
			-- https://fredrikaverpil.github.io/neotest-golang/
			"fredrikaverpil/neotest-golang",
			build = function()
				vim.system({ "go", "install", "gotest.tools/gotestsum@latest" }):wait() -- Optional, but recommended
			end,
		},
	},
	config = function()
		require("neotest").setup({
			-- ===== 1. 必需核心字段 =====
			adapters = {
				require("neotest-golang")({
					runner = "gotestsum",
				}),
			},
			discovery = {
				enabled = true,
				concurrent = 0, -- 0表示根据CPU自动设置 [citation:5]
			},
			running = {
				concurrent = true, -- 允许测试并发运行 [citation:5]
			},
			default_strategy = "integrated",

			-- ===== 2. 之前缺失的必需字段（补全类型检查）=====
			consumers = {},
			icons = {
				passed = "",
				failed = "",
				skipped = "",
				running = "",
				unknown = "",
			},
			highlights = {
				passed = "NeotestPassed",
				failed = "NeotestFailed",
				running = "NeotestRunning",
				skipped = "NeotestSkipped",
				test = "NeotestTest",
				namespace = "NeotestNamespace",
			},
			floating = {
				border = "rounded",
				max_height = 0.6,
				max_width = 0.6,
				options = {},
			},
			run = { enabled = true },
			output_panel = {
				enabled = true,
				open = "botright split | resize 15",
			},
			quickfix = {
				enabled = true,
				open = false,
			},
			state = { enabled = true },
			watch = {
				enabled = true,
				symbol_queries = {
					python = [[ (import_from_statement (_ (identifier) @symbol)) (import_statement (_ (identifier) @symbol)) ]],
					javascript = [[ (import_specifier name: (identifier) @symbol) (import_clause (identifier) @symbol) ]],
				},
			},
			diagnostic = {
				enabled = true,
				severity = vim.diagnostic.severity.ERROR,
			},
			projects = {},

			-- ===== 3. 常用功能与界面配置（可自定义）=====
			log_level = vim.log.levels.WARN,
			status = {
				enabled = true,
				signs = true,
				virtual_text = false,
			},
			summary = {
				enabled = true,
				open = "botright vsplit | vertical resize 50",
				follow = true,
				expand_errors = true,

				-- 新增的必需字段
				animated = true, -- 启用/禁用图标动画
				count = true, -- 在适配器名称旁显示测试数量

				mappings = {
					-- 您已配置的映射
					expand = { "<CR>", "<2-LeftMouse>" },
					run = "r",
					debug = "d",
					output = "o",
					short = "O",
					stop = "u",
					attach = "a",

					-- 新增的必需映射字段 (根据您的习惯设置快捷键)
					expand_all = "e",
					jumpto = "i",
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
				},
			},
			output = {
				enabled = true,
				open_on_run = "short",
			},
			strategies = {
				integrated = {
					width = 120,
					height = 40,
				},
			},
		})

		-- ===== 4. 推荐快捷键映射 =====
		vim.keymap.set("n", "<leader>rn", function()
			require("neotest").run.run()
		end, { desc = "Neotest: 运行最近测试" })
		vim.keymap.set("n", "<leader>rf", function()
			require("neotest").run.run(vim.fn.expand("%"))
		end, { desc = "Neotest: 运行当前文件" })
		vim.keymap.set("n", "<leader>rs", function()
			require("neotest").summary.toggle()
		end, { desc = "Neotest: 切换摘要面板" })
		vim.keymap.set("n", "<leader>ro", function()
			require("neotest").output_panel.toggle()
		end, { desc = "Neotest: 切换输出面板" })
	end,
}
