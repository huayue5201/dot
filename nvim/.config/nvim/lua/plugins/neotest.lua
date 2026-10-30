-- https://github.com/nvim-neotest/neotest

return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"antoinemadec/FixCursorHold.nvim",
		-- https://github.com/huayue5201/neotest-rust
		"huayue5201/neotest-rust",
		-- https://github.com/MisanthropicBit/neotest-busted
		"MisanthropicBit/neotest-busted",
		-- https://github.com/fredrikaverpil/neotest-golang
		-- 注意：仓库不在 nvim-neotest 组织下，写 nvim-neotest/neotest-golang 会 404
		"fredrikaverpil/neotest-golang",
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
					},

					-- （可选）指定用于调试的 DAP 适配器
					-- 默认为 "codelldb"，也可以改用 "lldb" 等
					dap_adapter = "codelldb",
				}),

				require("neotest-busted")({
					-- Leave as nil to let neotest-busted automatically find busted
					busted_command = nil,
					-- Do not use nvim to run busted, but run busted directly
					no_nvim = false,
					-- Extra arguments to busted
					busted_args = { "--shuffle-files" },
					-- 自定义 -u 配置；nil 时自动查找 minimal_init.lua
					minimal_init = nil,
					-- 只用项目内的 luarocks 安装（true 会忽略 ~/.luarocks 与全局安装）
					local_luarocks_only = false,
					-- Find parametric tests
					parametric_test_discovery = false,
				}),

				require("neotest-golang")({
					-- 直接调 go test（可换成 "gotestsum"，需自行安装）
					runner = "go",
					-- -count=1 关缓存，-race 抓数据竞争，-v 输出测试日志
					go_test_args = { "-v", "-race", "-count=1" },
					-- 调试测试走 nvim-dap-go（已配置 delve）
					dap_mode = "dap-go",
					-- Go 项目普遍用 testify suite，默认关闭会导致套件里的用例识别不到
					testify_enabled = true,
					-- 跳过 vendor 等非测试目录（默认列表 + vendor）
					filter_dirs = { ".git", "node_modules", ".venv", "venv", "vendor" },
					-- 非 UTF-8 输出清洗需额外依赖 uga-rosa/utf8，本仓不引入，保持默认关闭
					sanitize_output = false,
					log_level = vim.log.levels.ERROR,
				}),
			},
			-- 注意：neotest v6 已移除 overseer consumer（无 lua/neotest/consumers/overseer），
			-- 之前 require 它会导致整个 setup 报错、所有键位都不生效。
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
