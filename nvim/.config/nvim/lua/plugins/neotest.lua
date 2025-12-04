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
		---@diagnostic disable: missing-fields
		local config = {
			runner = "gotestsum", -- Optional, but recommended
		}
		require("neotest").setup({
			adapters = {
				require("neotest-golang")(config),
			},
			-- See all config options with :h neotest.Config
			discovery = {
				-- Drastically improve performance in ginormous projects by
				-- only AST-parsing the currently opened buffer.
				enabled = false,
				-- Number of workers to parse files concurrently.
				-- A value of 0 automatically assigns number based on CPU.
				-- Set to 1 if experiencing lag.
				concurrent = 1,
			},
			running = {
				-- Run tests concurrently when an adapter provides multiple commands to run.
				concurrent = true,
			},
			summary = {
				-- Enable/disable animation of icons.
				animated = false,
			},
		})

		-- ===== 4. 推荐快捷键映射 =====
		vim.keymap.set("n", "<leader>rt", function()
			require("neotest").run.run()
		end, { desc = "Neotest: 运行最近测试" })
		vim.keymap.set("n", "<leader>tf", function()
			require("neotest").run.run(vim.fn.expand("%"))
		end, { desc = "Neotest: 运行当前文件" })
		vim.keymap.set("n", "<leader>dt", function()
			require("neotest").run.run({ strategy = "dap" })
		end, { desc = "Neotest: debug最近的测试" })
		vim.keymap.set("n", "<leader>tt", function()
			require("neotest").summary.toggle()
		end, { desc = "Neotest: 切换摘要面板" })
		vim.keymap.set("n", "<leader>to", function()
			require("neotest").output_panel.toggle()
		end, { desc = "Neotest: 切换输出面板" })
		vim.keymap.set("n", "<leader>st", function()
			require("neotest").run.stop()
		end, { desc = "Neotest: 停止测试" })
	end,
}
