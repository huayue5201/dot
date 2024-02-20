-- https://github.com/mfussenegger/nvim-dap

return {
	"mfussenegger/nvim-dap",
	requires = {
		"rcarriga/nvim-dap-ui",
		"theHamsta/nvim-dap-virtual-text",
	},
	keys = {
		{ "<leader>d", desc = "设置断点" },
		{ "<F5>", desc = "断点执行" },
		{ "<F9>", desc = "单步执行(进入函数调用)" },
		{ "<F10>", desc = "单步执行" },
		{ "<leader>re", desc = "REPL" },
	},
	config = function()
		-- 断点标志
		vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "", linehl = "", numhl = "" })
		-- 设置断点
		vim.keymap.set("n", "<leader>d", "<cmd>lua require'dap'.toggle_breakpoint()<cr>")
		-- 断点执行
		vim.keymap.set("n", "<F5>", "<cmd>lua require'dap'.continue()<cr>")
		-- 单步执行并进入函数调用
		vim.keymap.set("n", "<F9>", "<cmd>lua require'dap'.step_over()<cr>")
		-- 单步执行
		vim.keymap.set("n", "<F10>", "<cmd>lua require'dap'.step_into()<cr>")
		-- 打开REPL
		vim.keymap.set("n", "<leader>re", "<cmd>lua require'dap'.step_over()<cr>")
	end,
}
