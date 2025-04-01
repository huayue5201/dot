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
	help = ":close<cr>",
	qf = ":close<cr>",
	checkhealth = ":close<cr>",
	man = ":quit<cr>",
	toggleterm = ":close<cr>",
	["grug-far"] = ":bdelete<cr>",
	terminal = ":close<cr>",
	git = ":bdelete<cr>",
	["dap-repl"] = ":close<cr>",
	["dap-float"] = ":close<cr>",
	nofile = ":bdelete<cr>",
	["dap-view"] = ":DapViewClose!<cr>",
	["dap-view-term"] = ":close<cr>",
	acwrite = ":bdelete<cr>",
}

return M
