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
	sidekick_terminal = {
		setup = function()
			local keys_to_disable = { "<c-o>", "<c-i>", "<c-q>" }
			local modes = { "n", "v" } -- n=普通, v=可视
			for _, mode in ipairs(modes) do
				for _, key in ipairs(keys_to_disable) do
					vim.keymap.set(mode, key, "<Nop>", { buffer = true, silent = true })
				end
			end
		end,
	},
}
