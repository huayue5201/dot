-- https://github.com/nvim-neotest/neotest

return {
	"nvim-neotest/neotest",
	event = "VeryLazy",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"antoinemadec/FixCursorHold.nvim",
		-- https://github.com/huayue5201/neotest-rust
		"huayue5201/neotest-rust",
		-- https://github.com/MisanthropicBit/neotest-busted
		"MisanthropicBit/neotest-busted",
	},
	config = function()
		local neotest = require("neotest")

		neotest.setup({
			adapters = {
				require("neotest-rust")({
					-- （可选）为 cargo nextest 传递额外参数
					-- 例如：显示测试中的打印输出
					args = { "--nocapture" },

					-- （可选）设置测试运行时的环境变量
					-- 例如：为测试设置特定的日志级别
					env = {
						RUST_LOG = "debug",
						MY_TEST_ENV_VAR = "my_value",
					},

					-- （可选）指定用于调试的 DAP 适配器
					-- 默认为 "codelldb"，也可以改用 "lldb" 等
					dap_adapter = "codelldb",
				}),

				require("neotest-busted")({
					-- Leave as nil to let neotest-busted automatically find busted
					busted_command = "<path to a busted executable>",
					-- Do not use nvim to run busted, but run busted directly
					no_nvim = false,
					-- Extra arguments to busted
					busted_args = { "--shuffle-files" },
					-- List of paths to add to lua path lookups before running
					-- busted, or a function returning a list of such paths
					busted_paths = { "my/custom/path/?.lua" },
					-- List of paths to add to lua cpath lookups before running
					-- busted, or a function returning a list of such paths
					busted_cpaths = { "my/custom/path/?.so" },
					-- Custom config to load via -u to set up testing.
					-- If nil, will look for a 'minimal_init.lua' file
					minimal_init = "custom_init.lua",
					-- Only use a luarocks installation in the project's directory. If
					-- true, installations in $HOME and global installations will be
					-- ignored. Useful for isolating the test environment
					local_luarocks_only = true,
					-- Find parametric tests
					parametric_test_discovery = false,
				}),
			},
			-- overseer任务插件集成.
			consumers = {
				overseer = require("neotest.consumers.overseer"),
			},
		})

		vim.keymap.set("n", "<leader>tr", function()
			neotest.run.run()
		end, { desc = "运行当前文件测试" })

		vim.keymap.set("n", "<leader>tf", function()
			neotest.run.run(vim.fn.expand("%"))
		end, { desc = "运行当前文件全部测试" })

		vim.keymap.set("n", "<leader>tT", function()
			neotest.run.run({ suite = true })
		end, { desc = "运行整个测试套件" })

		vim.keymap.set("n", "<leader>tl", function()
			neotest.run.run_last()
		end, { desc = "运行最近的测试" })

		vim.keymap.set("n", "<leader>td", function()
			neotest.run.run({ strategy = "dap" })
		end, { desc = "调试最近的测试 (DAP)" })

		vim.keymap.set("n", "<leader>ts", function()
			neotest.run.stop()
		end, { desc = "停止最近的测试" })

		vim.keymap.set("n", "<leader>ta", function()
			neotest.run.attach()
		end, { desc = "附加到最近的测试" })

		vim.keymap.set("n", "<leader>to", function()
			neotest.output.open({ enter = true, auto_close = true })
		end, { desc = "打开测试输出" })

		vim.keymap.set("n", "<leader>tp", function()
			neotest.output_panel.toggle()
		end, { desc = "切换测试输出面板" })

		vim.keymap.set("n", "<leader>tt", function()
			neotest.summary.toggle()
		end, { desc = "切换测试摘要" })

		vim.keymap.set("n", "<leader>tw", function()
			neotest.watch.toggle(vim.fn.expand("%"))
		end, { desc = "监听当前文件测试" })

		vim.keymap.set("n", "[T", function()
			neotest.jump.prev({ status = "failed" })
		end, { desc = "跳到上一个失败测试" })

		vim.keymap.set("n", "]T", function()
			neotest.jump.next({ status = "failed" })
		end, { desc = "跳到下一个失败测试" })
	end,
}
