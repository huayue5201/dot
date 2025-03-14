-- https://github.com/mfussenegger/nvim-dap

return {
	"mfussenegger/nvim-dap",
	config = function()
		vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "", linehl = "", numhl = "" })
	end,
}
