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

vim.api.nvim_create_user_command("SmartClose", function()
	require("user.utils").smart_close()
end, {})

-- 退出时捕获错误并写入当前项目根目录
-- vim.api.nvim_create_autocmd("VimLeavePre", {
-- 	pattern = "*",
-- 	callback = function()
-- 		-- 获取当前工作目录（项目根目录）
-- 		local project_root = vim.fn.getcwd()
--
-- 		-- 获取所有消息
-- 		local messages = vim.fn.execute("messages")
--
-- 		-- 筛选错误相关的消息
-- 		local errors = {}
-- 		for line in messages:gmatch("[^\r\n]+") do
-- 			if line:match("E%d+") or line:match("[Ee]rror") or line:match("[Ww]arning") or line:match("[Ff]ail") then
-- 				table.insert(errors, line)
-- 			end
-- 		end
--
-- 		-- 获取 v:errmsg
-- 		local errmsg = vim.fn.eval("v:errmsg")
--
-- 		-- 如果有错误,写入项目根目录
-- 		if #errors > 0 or (errmsg and errmsg ~= "") then
-- 			local log_file = project_root .. "/nvim_exit_error.log"
--
-- 			-- 构建日志内容
-- 			local log_content = {}
-- 			table.insert(log_content, "=== Neovim Exit Error ===")
-- 			table.insert(log_content, "Time: " .. os.date())
-- 			table.insert(log_content, "Project: " .. project_root)
-- 			table.insert(log_content, "=================================")
--
-- 			if errmsg and errmsg ~= "" then
-- 				table.insert(log_content, "v:errmsg: " .. errmsg)
-- 			end
--
-- 			if #errors > 0 then
-- 				table.insert(log_content, "\nError/Warning Messages:")
-- 				for _, err in ipairs(errors) do
-- 					table.insert(log_content, "  " .. err)
-- 				end
-- 			end
--
-- 			-- 追加到文件（每次退出都追加）
-- 			local file = io.open(log_file, "a")
-- 			if file then
-- 				file:write(table.concat(log_content, "\n") .. "\n\n")
-- 				file:close()
-- 				-- 在 Neovim 退出前打印提示（如果还能看到的话）
-- 				print("Error log saved to: " .. log_file)
-- 			end
-- 		end
-- 	end,
-- })
-- =============================================
-- 快捷键映射配置
-- =============================================
local utils = require("user.utils")
local buf_keymaps = utils.buf_keymaps

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "根据文件类型设置按键",
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	callback = function()
		local ft = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
		local bufname = vim.fn.bufname("%")
		local set_markers = vim.b.keymaps_set or {}

		for key, configs in pairs(buf_keymaps) do
			-- 只判断是否需要绑定按键，不再处理关闭逻辑
			local conf = configs[ft]

			if not conf and bufname:match("dap%-repl") then
				conf = configs["dap-repl"]
			end

			if conf and not set_markers[key] then
				vim.keymap.set("n", key, function()
					utils.smart_close()
				end, { buffer = true, silent = true, noremap = true, nowait = true })

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
