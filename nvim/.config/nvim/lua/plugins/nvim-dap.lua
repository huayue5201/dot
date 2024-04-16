-- https://github.com/mfussenegger/nvim-dap
-- https://github.com/rcarriga/nvim-dap-ui
-- https://github.com/theHamsta/nvim-dap-virtual-text

return {
	"mfussenegger/nvim-dap",
	dependencies = {
		"rcarriga/nvim-dap-ui",
		"nvim-neotest/nvim-nio",
		"theHamsta/nvim-dap-virtual-text",
		"nvim-treesitter/nvim-treesitter",
		"williamboman/mason.nvim",
	},
	keys = {
		{ "<leader>b", desc = "切换断点" },
		{ "<leader>B", desc = "设置日志断点" },
		{ "<leader>du", desc = "调试模式" },
		-- { "<leader>dl", desc = "运行上次的调试会话" },
		-- { "<leader>dr", desc = "REPL" },
		-- { "<leader>dh", desc = "鼠标悬停" },
		-- { "<leader>dp", desc = "预览" },
		-- { "<leader>df", desc = "展示调试框架" },
		-- { "<leader>ds", desc = "展示调试作用域" },
	},
	config = function()
		-- 定义调试器断点标志
		vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "", linehl = "", numhl = "" })

		-- 导入 dap 和 dapui 模块
		local dap, dapui = require("dap"), require("dapui")

		-- rcarriga/nvim-dap-ui配置
		dapui.setup({
			-- Set icons to characters that are more likely to work in every terminal.
			--    Feel free to remove or use ones that you like more! :)
			--    Don't feel like these are good choices.
			icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
			controls = {
				icons = {
					pause = "⏸",
					play = "▶",
					step_into = "⏎",
					step_over = "⏭",
					step_out = "⏮",
					step_back = "b",
					run_last = "▶▶",
					terminate = "⏹",
					disconnect = "⏏",
				},
			},
		})

		dap.listeners.after.event_initialized["dapui_config"] = dapui.open
		dap.listeners.before.event_terminated["dapui_config"] = dapui.close
		dap.listeners.before.event_exited["dapui_config"] = dapui.close

		-- theHamsta/nvim-dap-virtual-text配置
		require("nvim-dap-virtual-text").setup({
			virt_text_pos = "inline", -- 启用嵌入提示
		})

		-- 导入 dap_config.lua 模块
		local codelldb = require("dap-server.codelldb")

		-- 调用模块中的函数进行配置
		codelldb.setup_codelldb_adapter()
		codelldb.setup_cpp_configuration()

		-- 继续执行程序
		vim.keymap.set("n", "<F5>", function()
			dap.continue()
		end)

		-- 单步进入
		vim.keymap.set("n", "<F1>", function()
			dap.step_into()
		end)

		-- 单步跳过
		vim.keymap.set("n", "<F2>", function()
			dap.step_over()
		end)

		-- 单步退出
		vim.keymap.set("n", "<F3>", function()
			dap.step_out()
		end)

		-- 切换断点
		vim.keymap.set("n", "<Leader>b", function()
			dap.toggle_breakpoint()
		end)

		-- 设置日志断点
		vim.keymap.set("n", "<Leader>B", function()
			dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
		end)

		-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
		vim.keymap.set("n", "<F7>", dapui.toggle, { desc = "Debug: See last session result." })

		-- debug ui
		vim.keymap.set("n", "<leader>du", "<cmd>lua require'dapui'.toggle()<cr>")

		-- -- 打开REPL
		-- map("n", "<Leader>dr", function()
		-- 	dap.repl.open()
		-- end)

		-- -- 运行上次的调试会话
		-- map("n", "<Leader>dl", function()
		-- 	dap.run_last()
		-- end)

		-- -- 鼠标悬停
		-- map({ "n", "v" }, "<Leader>dh", function()
		-- 	require("dap.ui.widgets").hover()
		-- end)

		-- -- 预览
		-- map({ "n", "v" }, "<Leader>dp", function()
		-- 	require("dap.ui.widgets").preview()
		-- end)

		-- -- 展示调试框架
		-- map("n", "<Leader>df", function()
		-- 	local widgets = require("dap.ui.widgets")
		-- 	widgets.centered_float(widgets.frames)
		-- end)

		-- -- 展示调试作用域
		-- map("n", "<Leader>ds", function()
		-- 	local widgets = require("dap.ui.widgets")
		-- 	widgets.centered_float(widgets.scopes)
		-- end)
	end,
}
