-- 保存时自动删除尾随空格
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = { "*" },
	desc = "保存前自动删除行尾空格",
	command = "%s/\\s\\+$//e",
})

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

-- 文件类型特定的快捷键映射
local buf_keymaps = require("user.utils").buf_keymaps
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "根据文件类型设置按键",
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	callback = function()
		local ft = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
		local set_markers = vim.b.keymaps_set or {}

		for key, configs in pairs(buf_keymaps) do
			local conf = configs[ft]
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

-- 自动刷新 quickfix 和 location list
local timer = nil
local last_refresh = 0

vim.api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function()
		local now = vim.loop.now()
		if now - last_refresh < 300 then
			return
		end -- 300ms 冷却时间

		if timer then
			timer:close()
		end
		timer = vim.defer_fn(function()
			-- 刷新 quickfix
			local qf_info = vim.fn.getqflist()
			if #qf_info > 0 and qf_info[1].winid ~= 0 then
				require("lsp-config.lsp_keys").open_all_diagnostics()
			end

			-- 刷新当前窗口的 location list
			local loc_info = vim.fn.getloclist(0)
			if #loc_info > 0 and loc_info[1].winid ~= 0 then
				require("lsp-config.lsp_keys").open_buffer_diagnostics()
			end

			last_refresh = vim.loop.now()
			timer = nil
		end, 150) -- 150ms 防抖延迟
	end,
})
