-- https://github.com/mfussenegger/nvim-dap

return {
	"mfussenegger/nvim-dap",
	requires = {
		"rcarriga/nvim-dap-ui",
		"theHamsta/nvim-dap-virtual-text",
	},
	keys = {
		{ "<leader>B", desc = "设置断点" },
		{ "<leader>b", desc = "切换断点" },
		{ "<leader>lp", desc = "设置日志断点" },
		{ "<leader>dl", desc = "运行上次的调试会话" },
		{ "<leader>dr", desc = "REPL" },
		{ "<leader>dh", desc = "鼠标悬停" },
		{ "<leader>dp", desc = "预览" },
		{ "<leader>df", desc = "展示调试框架" },
		{ "<leader>ds", desc = "展示调试作用域" },
	},
	config = function()
		-- 断点标志
		vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "", linehl = "", numhl = "" })
		-- 使用Alacritty作为外部终端
		local dap = require("dap")
		dap.defaults.fallback.external_terminal = {
			command = "/usr/bin/alacritty",
			args = { "-e" },
		}
		-- 继续执行程序
		vim.keymap.set("n", "<F5>", function()
			require("dap").continue()
		end)

		-- 单步跳过
		vim.keymap.set("n", "<F10>", function()
			require("dap").step_over()
		end)

		-- 单步进入
		vim.keymap.set("n", "<F11>", function()
			require("dap").step_into()
		end)

		-- 单步退出
		vim.keymap.set("n", "<F12>", function()
			require("dap").step_out()
		end)

		-- 切换断点
		vim.keymap.set("n", "<Leader>b", function()
			require("dap").toggle_breakpoint()
		end)

		-- 设置断点
		vim.keymap.set("n", "<Leader>B", function()
			require("dap").set_breakpoint()
		end)

		-- 设置日志断点
		vim.keymap.set("n", "<Leader>lp", function()
			require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
		end)

		-- 打开REPL
		vim.keymap.set("n", "<Leader>dr", function()
			require("dap").repl.open()
		end)

		-- 运行上次的调试会话
		vim.keymap.set("n", "<Leader>dl", function()
			require("dap").run_last()
		end)

		-- 鼠标悬停
		vim.keymap.set({ "n", "v" }, "<Leader>dh", function()
			require("dap.ui.widgets").hover()
		end)

		-- 预览
		vim.keymap.set({ "n", "v" }, "<Leader>dp", function()
			require("dap.ui.widgets").preview()
		end)

		-- 展示调试框架
		vim.keymap.set("n", "<Leader>df", function()
			local widgets = require("dap.ui.widgets")
			widgets.centered_float(widgets.frames)
		end)

		-- 展示调试作用域
		vim.keymap.set("n", "<Leader>ds", function()
			local widgets = require("dap.ui.widgets")
			widgets.centered_float(widgets.scopes)
		end)
	end,
}
