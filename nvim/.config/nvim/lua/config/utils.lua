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
	["minideps-confirm"] = ":bdelete<cr>",
	terminal = ":close<cr>",
	git = ":bdelete<cr>",
	["dap-repl"] = ":close<cr>",
	["dap-float"] = ":close<cr>",
	nofile = ":bdelete<cr>",
	fugitive = ":bdelete<cr>",
	floggraph = ":close<cr>",
	["dap-view"] = ":close<cr>",
	["dap-view-term"] = ":close<cr>",
}

return M
