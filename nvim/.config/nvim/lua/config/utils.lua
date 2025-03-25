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
	fugitive = ":bdelete<cr>",
	floggraph = ":close<cr>",
	["dap-view"] = ":DapViewClose!<cr>",
	["dap-view-term"] = ":close<cr>",
	acwrite = ":bdelete<cr>",
}

M.executable_path = function()
	if vim.g.debug_file and vim.fn.filereadable(vim.g.debug_file) == 1 then
		return vim.g.debug_file
	else
		vim.notify("⚠️ No valid debug file set! Please mark a file with <A-a>", vim.log.levels.WARN)
		return nil -- 返回 nil 避免启动调试
	end
end

return M
