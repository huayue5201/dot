-- 自动删除尾随空格
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*",
	command = "%s/\\s\\+$//e",
})

-- ✨ 光标恢复位置
vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "记住最后的光标位置",
	group = vim.api.nvim_create_augroup("LastPlace", { clear = true }),
	pattern = "*",
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		if #lines > 0 and mark[1] > 0 and mark[1] <= #lines then
			vim.schedule(function()
				pcall(vim.api.nvim_win_set_cursor, 0, mark)
			end)
		end
	end,
})

local lsp = require("config.lsp")
lsp.mode_changed_handler() -- 设置模式变化时禁用/启用诊断
-- ✨ LSP 启动时绑定快捷键与功能
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
	callback = function(args)
		if not vim.g.lsp_enabled then
			vim.lsp.stop_client(args.data.client_id, true)
		else
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			-- print("LspAttach", client.name)
			-- local capabilities = vim.lsp.get_clients()[1].server_capabilities
			-- print(vim.inspect(capabilities))
			lsp.diagnostic_config() -- 设置诊断配置
			lsp.inlay_hint_handler() -- 设置插入模式内联提示处理
			lsp.set_keymaps() -- 设置按键映射

			vim.lsp.document_color.enable(true, args.buf)

			if client:supports_method("textDocument/foldingRange") then
				local win = vim.api.nvim_get_current_win()
				vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
			end

			if client:supports_method("textDocument/inlayHint") then
				-- vim.lsp.inlay_hint.enable(true, { bufnr = 0 })
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
			end

			if client:supports_method("textDocument/codeLens") then
				vim.lsp.codelens.refresh({ bufnr = 0 })
			end
			-- 自动刷新 CodeLens
			vim.cmd([[ autocmd BufEnter,CursorHold,InsertLeave <buffer> lua vim.lsp.codelens.refresh({ bufnr = 0 }) ]])
		end
	end,
})

vim.api.nvim_create_autocmd("LspDetach", {
	group = vim.api.nvim_create_augroup("LspStopAndUnmap", { clear = true }),
	callback = function(args)
		-- 获取 LSP 客户端
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client then
			-- 停止 LSP 客户端（当没有附加的缓冲区时）
			if not client.attached_buffers then
				client:stop()
			else
				for buf_id in pairs(client.attached_buffers) do
					if buf_id == args.buf then
						client:stop()
						break
					end
				end
			end
			-- 移除键映射
			lsp.remove_keymaps()
		end
	end,
	desc = "Stop LSP client and remove keymaps when no buffer is attached",
})

-- ✨ 通用 `q` 快捷键关闭窗口
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "用 q 关闭窗口或删除缓冲区",
	callback = function()
		local close_commands = require("utils.utils").close_commands
		local current_type = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
		local command = close_commands[current_type]
		if command then
			local opts = { buffer = true, noremap = true, silent = true }
			if type(command) == "function" then
				vim.keymap.set("n", "q", command, opts)
			else
				vim.keymap.set("n", "q", function()
					vim.cmd(command)
				end, opts)
			end
		end
	end,
})

-- ✨ 优化剪贴板操作
vim.cmd([[
function! YankShift()
  call setreg(0, getreg('"'))
  for i in range(9, 1, -1)
    call setreg(i, getreg(i - 1))
  endfor
endfunction

au TextYankPost * if v:event.operator == 'y' | call YankShift() | endif
au TextYankPost * if v:event.operator == 'd' | call YankShift() | endif
]])

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
	once = true,
	callback = function()
		if vim.fn.has("win32") == 1 or vim.fn.has("wsl") == 1 then
			vim.g.clipboard = {
				copy = {
					["+"] = "win32yank.exe -i --crlf",
					["*"] = "win32yank.exe -i --crlf",
				},
				paste = {
					["+"] = "win32yank.exe -o --lf",
					["*"] = "win32yank.exe -o --lf",
				},
			}
		elseif vim.fn.has("unix") == 1 then
			if vim.fn.executable("xclip") == 1 then
				vim.g.clipboard = {
					copy = {
						["+"] = "xclip -selection clipboard",
						["*"] = "xclip -selection clipboard",
					},
					paste = {
						["+"] = "xclip -selection clipboard -o",
						["*"] = "xclip -selection clipboard -o",
					},
				}
			elseif vim.fn.executable("xsel") == 1 then
				vim.g.clipboard = {
					copy = {
						["+"] = "xsel --clipboard --input",
						["*"] = "xsel --clipboard --input",
					},
					paste = {
						["+"] = "xsel --clipboard --output",
						["*"] = "xsel --clipboard --output",
					},
				}
			end
		end

		vim.opt.clipboard = "unnamedplus"
	end,
	desc = "Lazy load clipboard",
})

-- -- ✨ 复制前记录光标位置
-- local cursorPreYank
-- vim.keymap.set({ "n", "x" }, "y", function()
-- 	cursorPreYank = vim.api.nvim_win_get_cursor(0)
-- 	return "y"
-- end, { expr = true })
-- vim.keymap.set("n", "Y", function()
-- 	cursorPreYank = vim.api.nvim_win_get_cursor(0)
-- 	return "y$"
-- end, { expr = true })
--
-- -- ✨ 高亮复制 & 光标恢复 & 剪贴板同步
-- vim.api.nvim_create_autocmd("TextYankPost", {
-- 	pattern = "*",
-- 	callback = function()
-- 		vim.hl.on_yank({ timeout = 330 })
--
-- 		if vim.v.event.operator == "y" and cursorPreYank then
-- 			vim.schedule(function()
-- 				vim.api.nvim_win_set_cursor(0, cursorPreYank)
-- 				cursorPreYank = nil
-- 			end)
-- 		end
--
-- 		if vim.fn.has("clipboard") == 1 then
-- 			local reg_type = vim.fn.getregtype('"')
-- 			if reg_type ~= "+" then
-- 				local clipboard_content = vim.fn.getreg('"')
-- 				if clipboard_content ~= "" then
-- 					vim.defer_fn(function()
-- 						vim.fn.setreg("+", clipboard_content)
-- 					end, 20)
-- 				end
-- 			end
-- 		end
-- 	end,
-- })

-- 定义删除 quickfix 或 location list 项目的函数
local function delete_qf_items()
	local win_id = vim.api.nvim_get_current_win()
	local win_info = vim.fn.getwininfo(win_id)[1]
	local is_loc = win_info and win_info.loclist == 1
	local is_qf = win_info and win_info.quickfix == 1 and not is_loc

	if not (is_qf or is_loc) then
		return
	end

	local list = is_qf and vim.fn.getqflist() or vim.fn.getloclist(0)
	if not list or #list == 0 then
		return
	end

	-- 获取当前模式
	local mode = vim.api.nvim_get_mode().mode
	local start_idx, end_idx

	if mode == "n" then
		-- 普通模式：删除当前行（或 count 指定的多行）
		start_idx = vim.fn.line(".")
		end_idx = start_idx + (vim.v.count > 0 and vim.v.count - 1 or 0)
	else
		-- 可视模式：删除选中行
		start_idx = vim.fn.line("v")
		end_idx = vim.fn.line(".")
		vim.cmd("normal! <esc>") -- 退出可视模式
	end

	-- 确保索引有效
	start_idx = math.max(1, math.min(start_idx, #list))
	end_idx = math.max(1, math.min(end_idx, #list))
	if start_idx > end_idx then
		start_idx, end_idx = end_idx, start_idx
	end

	-- 创建新的列表（排除要删除的项目）
	local new_list = {}
	for i = 1, #list do
		if i < start_idx or i > end_idx then
			table.insert(new_list, list[i])
		end
	end

	-- 更新列表
	if is_qf then
		vim.fn.setqflist(new_list, "r")
	else
		vim.fn.setloclist(0, new_list, "r")
	end

	-- 调整光标位置
	local new_pos = math.min(start_idx, #new_list)
	if new_pos > 0 then
		vim.fn.cursor(new_pos, 1)
	end
end

-- FileType 自动命令，针对 quickfix 和 location list 做一些设置
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("QuickfixTweaks", { clear = true }),
	pattern = "qf",
	desc = "Quickfix and location list tweaks",
	callback = function()
		local win_id = vim.api.nvim_get_current_win()
		local win_info = vim.fn.getwininfo(win_id)[1]

		local is_loc = win_info and win_info.loclist == 1
		local is_qf = win_info and win_info.quickfix == 1 and not is_loc

		-- 禁用 buffer 列表，防止显示在 buffer list 中
		vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })

		-- 根据不同类型设置关闭命令
		local close_cmd = is_qf and "<CMD>cclose<CR>" or "<CMD>lclose<CR>"

		-- 设置快捷键
		vim.keymap.set("n", "<ESC>", close_cmd, { buffer = true, silent = true })
		vim.keymap.set("n", "dd", delete_qf_items, { buffer = true, desc = "Delete current item" })
		vim.keymap.set("x", "d", delete_qf_items, { buffer = true, desc = "Delete selected items" })
		vim.keymap.set("n", "q", close_cmd, { buffer = true, silent = true })

		-- 快捷键切换到下一个/上一个条目
		if is_qf then
			vim.keymap.set("n", "L", "<CMD>cnext<CR>", { buffer = true, desc = "Next quickfix item" })
			vim.keymap.set("n", "H", "<CMD>cprev<CR>", { buffer = true, desc = "Previous quickfix item" })
		elseif is_loc then
			vim.keymap.set("n", "L", "<CMD>lnext<CR>", { buffer = true, desc = "Next location item" })
			vim.keymap.set("n", "H", "<CMD>lprev<CR>", { buffer = true, desc = "Previous location item" })
		end

		-- 更新状态栏显示
		local list_type = is_qf and "Quickfix" or "Location List"
		vim.opt_local.statusline = list_type .. " %<%f %=%-14.(%l/%L%)%P"
	end,
})

-- 检查指定类型窗口是否已打开
local function is_window_open(win_type)
	for _, win in ipairs(vim.fn.getwininfo()) do
		-- 修复：使用正确的键名检查窗口类型
		if win_type == "quickfix" and win.quickfix == 1 then
			return true
		elseif win_type == "loclist" and win.loclist == 1 then
			return true
		end
	end
	return false
end

-- 创建一个切换窗口的通用命令
vim.api.nvim_create_user_command("Toggle", function(opts)
	local win_type = opts.fargs[1] or "quickfix"
	if win_type == "quickfix" then
		if is_window_open("quickfix") then
			vim.cmd("cclose") -- 如果 Quickfix 窗口已打开，关闭该窗口
		else
			vim.cmd("copen") -- 如果 Quickfix 窗口未打开，打开该窗口
		end
	elseif win_type == "loclist" then
		if is_window_open("loclist") then
			vim.cmd("lclose") -- 如果 Location List 窗口已打开，关闭该窗口
		else
			local locationList = vim.fn.getloclist(0)
			if #locationList > 0 then
				vim.cmd("lopen") -- 如果有可用的 Location List，打开该窗口
			else
				vim.notify("当前没有 loclist 可用", vim.log.levels.WARN) -- 如果没有可用的 Location List，发出警告
			end
		end
	end
end, { desc = "切换窗口", nargs = "?" })
