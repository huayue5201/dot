-- https://github.com/mfussenegger/nvim-dap

return {
	"mfussenegger/nvim-dap",
	keys = {
		{ "<leader>d", "<cmd>lua require'dap'.toggle_breakpoint()<cr>", desc = "标记断点" },
		{ "<leader>rd", "<cmd>lua require'dap'.continue()<cr>", desc = "执行dap调试" },
	},
	config = function()
		-- 断点图标设置
		vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "", linehl = "", numhl = "" })
	end,
}
