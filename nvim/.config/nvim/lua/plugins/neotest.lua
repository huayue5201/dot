-- https://github.com/nvim-neotest/neotest

return {
	"nvim-neotest/neotest",
	event = "BufReadPost",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"fredrikaverpil/neotest-golang",
	},
	config = function()
		-- neotest 配置
		require("neotest").setup({
			-- 设置测试适配器
			adapters = {

				-- 配置 Go 测试适配器
				require("neotest-golang")({
					-- 设置 go test 命令
					command = "go",
					args = { "test", "-v" }, -- 使用 go test 命令并输出详细信息
				}),

				-- JavaScript/TypeScript (jest)
				-- require("neotest-jest")({
				-- 	-- Jest 的命令行配置
				-- 	jestCommand = "jest --watchAll --no-cache --coverage",
				-- 	env = {
				-- 		NODE_ENV = "test",
				-- },
				-- }),
			},
			-- 设置测试运行器的行为
			strategies = {
				"neotest.strategy.term", -- 在终端中运行测试
				"neotest.strategy.integrated", -- 在 Neovim 内部集成运行测试
			},

			-- 设置 Neotest 窗口和信息显示
			icons = {
				passed = "✔",
				failed = "✘",
				running = "➤",
			},

			-- 测试结果展示
			output = {
				show_failed = true, -- 仅展示失败的测试
				show_passing = true, -- 展示成功的测试
				show_running = true, -- 展示运行中的测试
			},

			-- 测试时显示详细日志
			logging = true,

			-- 其他配置选项
			display = {
				-- 是否启用测试覆盖率报告
				show_coverage = true,
				-- 设置最大执行超时时间
				timeout = 5000,
			},

			-- 快捷键配置
			mappings = {
				-- 运行当前文件的所有测试
				run_all = "<Leader>oa", -- 运行所有测试
				-- 运行当前测试
				run_current = "<Leader>or", -- 运行当前测试
				-- 跳转到失败的测试
				jump_to_failed = "<Leader>of", -- 跳转到失败测试
			},
		})
	end,
}
