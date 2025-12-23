-- 保存时自动删除尾随空格
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = { "*" },
	desc = "保存前自动删除行尾空格",
	command = "%s/\\s\\+$//e",
})

-- 清除所有 Neovim 标记（包括全局）
vim.api.nvim_create_user_command("ClearAllMarks", function()
	-- 1. 清除所有 buffer-local marks
	vim.cmd("delmarks a-zA-Z0-9")
	-- 2. 清除特殊 marks
	vim.cmd("delmarks \"'[]<>")
	-- 3. 清除全局 marks（需要 Lua API）
	local marks = vim.fn.getmarklist()
	for _, mark in ipairs(marks) do
		local m = mark.mark
		if m:match("[A-Z]") then
			vim.cmd("delmarks " .. m)
		end
	end
	print("✅ 已清除所有标记（含全局）")
end, {})

vim.api.nvim_create_user_command("SmartClose", function()
	vim.schedule(function()
		local win = vim.api.nvim_get_current_win()
		local cfg = vim.api.nvim_win_get_config(win)
		-- 如果是浮动窗口（relative 不为空）
		if cfg.relative ~= "" then
			vim.api.nvim_win_close(win, false)
			return
		end
		-- 普通窗口逻辑
		if vim.fn.winnr("$") > 1 then
			vim.cmd("quit")
		else
			vim.cmd("bdelete")
		end
	end)
end, {})

-- 恢复上次光标位置
vim.cmd([[
augroup RestoreCursor
  autocmd!
  autocmd BufReadPre * autocmd FileType <buffer> ++once
    \ let s:line = line("'\"")
    \ | if s:line >= 1 && s:line <= line("$") && &filetype !~# 'commit'
    \      && index(['xxd', 'gitrebase'], &filetype) == -1
    \      && !&diff
    \ |   execute "normal! g`\""
    \ | endif
augroup END
]])

-- =============================================
-- 快捷键映射配置
-- =============================================

local buf_keymaps = require("user.utils").buf_keymaps
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "根据文件类型设置按键",
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	callback = function()
		local ft = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
		local bufname = vim.fn.bufname("%")
		local set_markers = vim.b.keymaps_set or {}

		for key, configs in pairs(buf_keymaps) do
			-- 优先匹配 filetype / buftype
			local conf = configs[ft]

			-- 如果没有匹配，再尝试 bufname 特殊匹配
			if not conf and bufname:match("dap%-repl") then
				conf = configs["dap-repl"]
			end

			if conf and not set_markers[key] then
				local opts = { buffer = true, silent = true, noremap = true, nowait = true }
				if type(conf.cmd) == "function" then
					vim.keymap.set("n", key, conf.cmd, opts)
				else
					vim.keymap.set("n", key, function()
						vim.cmd(conf.cmd)
					end, opts)
				end
				set_markers[key] = true
			end
		end

		vim.b.keymaps_set = set_markers
	end,
})

local buffer_settings = require("user.utils").settings
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "根据文件类型/缓冲区类型应用",
	group = vim.api.nvim_create_augroup("CustomBufferSettings", { clear = true }),
	callback = function(args)
		local buf = args.buf
		local ft = vim.bo[buf].filetype
		local bt = vim.bo[buf].buftype
		-- 选择优先 filetype，其次 buftype
		local kind = (ft ~= "" and ft) or bt
		-- 匹配 filetype/buftype
		if buffer_settings[kind] then
			buffer_settings[kind].setup()
		end
	end,
})
