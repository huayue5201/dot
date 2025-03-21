-- https://github.com/mfussenegger/nvim-dap

-- 参考:https://github.com/wookayin/dotfiles/blob/master/nvim/lua/config/dap.lua

return {
	"mfussenegger/nvim-dap",
	ft = { "rust", "c" },
	dependencies = {
		-- https://github.com/igorlfs/nvim-dap-view
		{ "igorlfs/nvim-dap-view", opts = {} },
	},
	config = function()
		local signs = {
			DapBreakpoint = { text = "🔴", texthl = "DapBreakpoint" },
			DapBreakpointCondition = { text = "🟡", texthl = "DapBreakpointCondition" },
			DapBreakpointRejected = { text = "⭕", texthl = "DapBreakpointRejected" },
			DapStopped = {
				text = " ",
				texthl = "DapBreakpoint",
				linehl = "DapCurrentLine",
				numhl = "DiagnosticSignWarn",
			},
		}
		for name, opts in pairs(signs) do
			vim.fn.sign_define(name, opts)
		end

		-- 加载dap调试配置
		-- require("dap.probe-rs")
		local dap = require("dap")
		-- require("dap.ext.vscode").load_launchjs()
		local widgets = require("dap.ui.widgets")

		-- 设置/删除断点
		vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { silent = true, desc = "Conditional Breakpoint" })

		vim.keymap.set(
			"n",
			"<leader>ib",
			function()
				vim.ui.input(
					{ prompt = "Breakpoint condition: " }, -- 弹出框提示语
					function(input)
						require("dap").set_breakpoint(input) -- 设置条件断点
					end
				)
			end,
			{ desc = "Conditional Breakpoint" } -- 快捷键描述
		)

		vim.keymap.set("n", "<leader>od", dap.continue, { silent = true, desc = "DAP Continue" })

		vim.keymap.set(
			"n", -- 正常模式
			"<leader>dl", -- 按键设置为 F17
			function()
				require("dap").run_last() -- 运行上次的调试会话
			end,
			{ desc = "Run Last" } -- 快捷键描述
		)

		vim.keymap.set("n", "<leader>do", dap.step_over, { silent = true, desc = "Step Over" })

		vim.keymap.set("n", "<leader>di", dap.step_into, { silent = true, desc = "Step Into" })

		vim.keymap.set("n", "<leader>dt", dap.step_out, { silent = true, desc = "Step Out" })

		vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { silent = true, desc = "Toggle DAP REPL" })

		vim.keymap.set("n", "<leader>dc", dap.run_to_cursor, { silent = true, desc = "Run to Cursor" })

		vim.keymap.set("n", "<leader>dk", function()
			widgets.hover(nil, { border = "rounded" })
		end, { desc = "Hover variable value" })

		vim.keymap.set("n", "<leader>dp", widgets.preview, { desc = "Preview variable value" })

		vim.keymap.set("n", "<leader>df", function()
			widgets.centered_float(widgets.scopes, { border = "shadow" })
		end, { desc = "Centered float for scopes" })

		vim.keymap.set("n", "<leader>dv", function()
			require("dap-view").toggle()
		end, { desc = "Toggle nvim-dap-view" })
	end,
}
