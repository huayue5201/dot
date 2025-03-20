-- https://github.com/mfussenegger/nvim-dap
-- https://github.com/igorlfs/nvim-dap-view

-- 参考:https://github.com/wookayin/dotfiles/blob/master/nvim/lua/config/dap.lua

return {
	"mfussenegger/nvim-dap",
	event = "BufReadPost",
	dependencies = {
		{ "igorlfs/nvim-dap-view", opts = {} },
	},
	config = function()
		vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "DapBreakpoint" })
		vim.fn.sign_define("DapBreakpointCondition", { text = "🟡", texthl = "DapBreakpointCondition" })
		vim.fn.sign_define("DapBreakpointRejected", { text = "⭕", texthl = "DapBreakpointRejected" })
		vim.fn.sign_define("DapStopped", {
			text = "▶",
			texthl = "DapBreakpoint",
			linehl = "DapCurrentLine",
			numhl = "DiagnosticSignWarn",
		})

		-- 加载dap调试配置
		require("dap.openocd")
		local dap = require("dap")
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
		vim.keymap.set("n", "<F5>", dap.continue, { silent = true, desc = "DAP Continue" })

		vim.keymap.set(
			"n", -- 正常模式
			"<F7>", -- 按键设置为 F17
			function()
				require("dap").run_last() -- 运行上次的调试会话
			end,
			{ desc = "Run Last" } -- 快捷键描述
		)

		vim.keymap.set("n", "<F10>", dap.step_over, { silent = true, desc = "Step Over" })

		vim.keymap.set("n", "<F11>", dap.step_into, { silent = true, desc = "Step Into" })

		vim.keymap.set("n", "<F12>", dap.step_out, { silent = true, desc = "Step Out" })

		vim.keymap.set("n", "<leader>dr", dap.repl.toggle, { silent = true, desc = "Toggle DAP REPL" })

		vim.keymap.set("n", "<leader>dv", dap.run_to_cursor, { silent = true, desc = "Run to Cursor" })

		vim.keymap.set("n", "<leader>dh", function()
			widgets.hover(nil, { border = "rounded" })
		end, { desc = "Hover variable value" })

		vim.keymap.set("n", "<leader>dp", widgets.preview, { desc = "Preview variable value" })

		vim.keymap.set("n", "<leader>dc", function()
			widgets.centered_float(widgets.scopes, { border = "shadow" })
		end, { desc = "Centered float for scopes" })
	end,
}
