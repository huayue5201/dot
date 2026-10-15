-- 缓冲区特殊设置（数据）
-- 格式：filetype/buftype -> { setup = function }
return {
	["dap-repl"] = {
		setup = function()
			vim.opt_local.confirm = false
			vim.opt.buflisted = false
		end,
	},
	["neotest-output"] = {
		setup = function()
			vim.opt_local.winfixbuf = true
			vim.opt.buflisted = false
		end,
	},
	terminal = {
		setup = function()
			vim.opt_local.winfixbuf = true
		end,
	},
}
