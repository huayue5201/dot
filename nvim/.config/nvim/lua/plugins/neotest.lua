-- https://github.com/nvim-neotest/neotest

return {
	"nvim-neotest/neotest",
	event = "VeryLazy",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"nvim-neotest/neotest-python",
		-- https://github.com/MisanthropicBit/neotest-busted
		"MisanthropicBit/neotest-busted",
		{
			dir = "~/neovim-plugins/neotest-rust",
			"huayue5201/neotest-rust",
			dev = true,
		},
	},
	config = function()
		local neotest = require("neotest")
		local nio = require("nio")

		neotest.setup({
			-- ============================================================
			-- 适配器配置
			-- ============================================================
			adapters = {
				-- Rust 适配器
				require("neotest-rust")({
					args = {
						"--nocapture",
						-- "--test-threads=1",
					},
					env = {
						RUST_BACKTRACE = "full",
						RUST_LOG = "debug",
						RUST_TEST_THREADS = "1",
					},
					dap_adapter = "codelldb",
					extra_args = {
						"--no-capture",
						"--show-progress=bar",
						"--status-level=all",
						"--final-status-level=all",
						"--failure-output=immediate-final",
						"--success-output=final",
						"--no-output-indent",
					},
				}),

				-- Python 适配器
				require("neotest-python")({
					dap = { justMyCode = false },
					args = { "--log-level", "DEBUG" },
					runner = "pytest",
					python = ".venv/bin/python",
					is_test_file = function(file_path)
						return file_path:match("test_.*%.py$") or file_path:match(".*_test%.py$")
					end,
					pytest_discover_instances = true,
				}),

				-- Lua/Busted 适配器
				require("neotest-busted")({
					busted_command = nil,
					no_nvim = false,
					busted_args = {
						"--output=busted",
						"--defer-print",
						"--shuffle=none",
					},
					busted_paths = function()
						local paths = {}
						local root = vim.fn.getcwd()
						table.insert(paths, root .. "/src/?.lua")
						table.insert(paths, root .. "/lib/?.lua")
						table.insert(paths, root .. "/lua/?.lua")
						table.insert(paths, root .. "/spec/?.lua")
						table.insert(paths, root .. "/test/?.lua")
						return paths
					end,
					busted_cpaths = function()
						local paths = {}
						local root = vim.fn.getcwd()
						table.insert(paths, root .. "/lib/?.so")
						return paths
					end,
					minimal_init = nil,
					local_luarocks_only = false,
					parametric_test_discovery = true,
				}),
			},

			-- ============================================================
			-- 消费者配置
			-- ============================================================
			consumers = {
				overseer = require("neotest.consumers.overseer"),
			},

			-- ============================================================
			-- 🔥 关键修复：输出窗口配置（这里被你放在了错误的位置）
			-- ============================================================
			output = {
				enabled = true,
				open_on_run = "long", -- 改为 "long" 或 true，不是 "short"
				-- "short": 只在有错误/失败时打开
				-- "long": 总是打开
				-- true: 总是打开
				-- false: 不自动打开
			},

			output_panel = {
				enabled = true,
				open = "botright split | resize 15",
			},

			-- ============================================================
			-- 其他 UI 配置
			-- ============================================================
			floating = {
				options = { winblend = 10 },
			},

			quickfix = {
				enabled = true,
				open = true,
			},

			summary = {
				enabled = true,
				open = "botright vsplit | vertical resize 50",
			},
		})

		-- ============================================================
		-- 键位映射
		-- ============================================================
		local opts = { noremap = true, silent = true }

		vim.keymap.set({ "x", "n" }, "<leader>tr", function()
			nio.run(function()
				neotest.run.run()
			end)
		end, vim.tbl_extend("force", opts, { desc = "Run nearest test" }))

		vim.keymap.set("n", "<leader>tf", function()
			nio.run(function()
				neotest.run.run(vim.fn.expand("%"))
			end)
		end, vim.tbl_extend("force", opts, { desc = "Run file tests" }))

		vim.keymap.set("n", "<leader>ta", function()
			nio.run(function()
				neotest.run.run({ suite = true })
			end)
		end, vim.tbl_extend("force", opts, { desc = "Run all tests" }))

		vim.keymap.set("n", "<leader>tl", function()
			nio.run(function()
				neotest.run.run_last()
			end)
		end, vim.tbl_extend("force", opts, { desc = "Run last test" }))

		vim.keymap.set("n", "<leader>td", function()
			nio.run(function()
				neotest.run.run({ strategy = "dap" })
			end)
		end, vim.tbl_extend("force", opts, { desc = "Debug nearest test" }))

		-- 🔥 打开输出窗口（测试结果详情）
		vim.keymap.set("n", "<leader>to", function()
			nio.run(function()
				neotest.output.open({ enter = true, short = false })
			end)
		end, vim.tbl_extend("force", opts, { desc = "Open test output" }))

		-- 🔥 打开输出面板（实时流输出）
		vim.keymap.set("n", "<leader>tp", function()
			nio.run(function()
				neotest.output_panel.toggle()
			end)
		end, vim.tbl_extend("force", opts, { desc = "Toggle output panel" }))

		vim.keymap.set("n", "<leader>ts", function()
			nio.run(function()
				neotest.run.stop()
			end)
		end, vim.tbl_extend("force", opts, { desc = "Stop test run" }))

		vim.keymap.set("n", "<leader>tt", function()
			nio.run(function()
				neotest.summary.toggle()
			end)
		end, vim.tbl_extend("force", opts, { desc = "Toggle test summary" }))

		vim.keymap.set("n", "<leader>tj", function()
			nio.run(function()
				neotest.jump.last()
			end)
		end, vim.tbl_extend("force", opts, { desc = "Jump to last test" }))

		vim.keymap.set("n", "<leader>tw", function()
			nio.run(function()
				neotest.watch.toggle()
			end)
		end, vim.tbl_extend("force", opts, { desc = "Toggle watch mode" }))

		vim.keymap.set("n", "<leader>tm", function()
			nio.run(function()
				neotest.summary.run_marked()
			end)
		end, vim.tbl_extend("force", opts, { desc = "Run marked tests" }))
	end,
}
