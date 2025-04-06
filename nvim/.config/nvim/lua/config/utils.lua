local M = {}

M.icons = {
	diagnostic = {
		ERROR = "󰅚 ",
		WARN = "󰀪 ",
		HINT = " ",
		INFO = " ",
	},
}

M.close_commands = {
	help = "close",
	qf = "close",
	checkhealth = "close",
	man = "quit",
	toggleterm = "close",
	["grug-far"] = "bdelete",
	terminal = "close",
	git = "bdelete",
	["dap-repl"] = "close",
	["dap-float"] = "close",
	nofile = "bdelete",
	DiffviewFileHistory = function()
		vim.cmd("DiffviewClose")
	end,
	["dap-view"] = function()
		vim.cmd("DapViewClose!")
	end,
	["dap-view-term"] = "close",
}

return M
