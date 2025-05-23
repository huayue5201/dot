-- -- 错误捕捉模块
-- vim.api.nvim_create_autocmd("VimLeave", {
-- 	callback = function()
-- 		local log_file = vim.fn.stdpath("config") .. "/logfile.txt"
-- 		local file = io.open(log_file, "a")
-- 		if file then
-- 			local err = vim.fn.execute("messages") -- 获取错误信息
-- 			file:write("Neovim closed with the following errors:\n")
-- 			file:write(err)
-- 			file:write("\n\n")
-- 			file:close()
-- 		end
-- 	end,
-- })

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

local lsp_config = require("config.lsp")
-- ✨ LSP 启动时绑定快捷键与功能
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		-- print("LspAttach", client.name)
		-- local capabilities = vim.lsp.get_clients()[1].server_capabilities
		-- print(vim.inspect(capabilities))
		lsp_config.diagnostic_config() -- 设置诊断配置
		lsp_config.diagnostic_handler() -- 设置诊断处理器
		lsp_config.mode_changed_handler() -- 设置模式变化时禁用/启用诊断
		lsp_config.inlay_hint_handler() -- 设置插入模式内联提示处理
		lsp_config.set_keymaps() -- 设置按键映射

		vim.lsp.document_color.enable(true, args.buf)
		-- vim.lsp.document_color.enable(not vim.lsp.document_color.is_enabled())

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
	end,
})

-- lsp退出时自动注销相关映射
vim.api.nvim_create_autocmd("LspDetach", {
	group = vim.api.nvim_create_augroup("UserLspDetach", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client then
			-- 移除键映射
			lsp_config.remove_keymaps()
		end
	end,
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

-- -- ✨ 删除 quickfix / loclist 条目工具函数
-- local function delete_qf_items()
-- 	local is_qf = vim.fn.getwininfo(vim.fn.win_getid())[1].quickfix == 1
-- 	local qflist = is_qf and vim.fn.getqflist() or vim.fn.getloclist(0)
-- 	if not qflist or #qflist == 0 then
-- 		return
-- 	end
--
-- 	local mode = vim.api.nvim_get_mode().mode
-- 	local start_idx, count
-- 	if mode == "n" then
-- 		start_idx = vim.fn.line(".")
-- 		count = vim.v.count > 0 and vim.v.count or 1
-- 	else
-- 		local v_start_idx = vim.fn.line("v")
-- 		local v_end_idx = vim.fn.line(".")
-- 		start_idx = math.min(v_start_idx, v_end_idx)
-- 		count = math.abs(v_end_idx - v_start_idx) + 1
-- 		vim.cmd("normal! <esc>")
-- 	end
--
-- 	if start_idx < 1 or start_idx > #qflist then
-- 		return
-- 	end
--
-- 	for _ = 1, count do
-- 		if start_idx <= #qflist then
-- 			table.remove(qflist, start_idx)
-- 		end
-- 	end
--
-- 	if is_qf then
-- 		vim.fn.setqflist(qflist, "r")
-- 	else
-- 		vim.fn.setloclist(0, qflist, "r")
-- 	end
--
-- 	local new_pos = math.min(start_idx, #qflist)
-- 	if new_pos > 0 then
-- 		vim.fn.cursor(new_pos, 1)
-- 	end
-- end
--
-- -- ✨ Quickfix 窗口定制
-- vim.api.nvim_create_autocmd("FileType", {
-- 	group = vim.api.nvim_create_augroup("QuickfixTweaks", { clear = true }),
-- 	pattern = "qf",
-- 	desc = "Quickfix tweaks",
-- 	callback = function()
-- 		vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })
-- 		vim.keymap.set("n", "<ESC>", "<CMD>cclose<CR>", { buffer = true, silent = true })
-- 		vim.keymap.set("n", "dd", delete_qf_items, { buffer = true })
-- 		vim.keymap.set("x", "d", delete_qf_items, { buffer = true })
-- 	end,
-- })
