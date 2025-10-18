-- =============================================
-- 编辑器行为与模式配置
-- =============================================

-- 根据模式变化调整 virtualedit 设置
vim.api.nvim_create_autocmd("ModeChanged", {
	pattern = "*:*",
	desc = "根据编辑模式调整 virtualedit 设置",
	callback = function()
		local mode = vim.fn.mode()
		if mode == "n" or mode == "\22" then -- 普通模式或 Ctrl-V
			vim.opt.virtualedit = "all"
		end
		if mode == "i" then -- 插入模式
			vim.opt.virtualedit = "block"
		end
		if mode == "v" or mode == "V" then -- 可视模式或可视行模式
			vim.opt.virtualedit = "onemore"
		end
	end,
})

-- 保存时自动删除尾随空格
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*",
	desc = "保存前自动删除行尾空格",
	command = "%s/\\s\\+$//e",
})

-- 恢复上次光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "打开文件时恢复上次光标位置",
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

-- =============================================
-- LSP 语言服务器协议配置
-- =============================================

-- 初始化 LSP 配置
local lsp_config = require("config.lsp")

-- LSP 附加到缓冲区时的配置
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
	desc = "LSP 客户端附加到缓冲区时的配置",
	callback = function(args)
		if not vim.g.lsp_enabled then
			vim.lsp.stop_client(args.data.client_id, true)
		else
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			lsp_config.diagnostic_config() -- 设置诊断配置
			lsp_config.inlay_hint_handler() -- 设置插入模式内联提示处理
			lsp_config.set_keymaps() -- 设置 LSP 按键映射
			lsp_config.mode_changed_handler() -- 设置模式变化时禁用/启用诊断
			-- 启用文档颜色高亮
			vim.lsp.document_color.enable(true, 0, { style = "virtual" })

			-- 启用 LSP 折叠
			if client:supports_method("textDocument/foldingRange") then
				local win = vim.api.nvim_get_current_win()
				vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
			end

			-- 启用内联提示
			if client:supports_method("textDocument/inlayHint") then
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
			end
		end
	end,
})

-- LSP 从缓冲区分离时的清理
vim.api.nvim_create_autocmd("LspDetach", {
	group = vim.api.nvim_create_augroup("LspStopAndUnmap", { clear = true }),
	desc = "LSP 客户端分离时停止客户端并移除键映射",
	callback = function(args)
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
			lsp_config.remove_keymaps()
		end
	end,
})

-- 根据文件类型启动 LSP
local lsp_get = require("utils.lsp_utils")
vim.api.nvim_create_autocmd("FileType", {
	desc = "根据文件类型启动或停止 LSP",
	pattern = lsp_get.get_lsp_config("filetypes"),
	callback = function()
		if vim.g.lsp_enabled then
			vim.lsp.enable(lsp_get.get_lsp_name())
		else
			vim.lsp.stop_client(lsp_get.get_lsp_name())
		end
	end,
})

-- =============================================
-- 快捷键映射配置
-- =============================================

-- 文件类型特定的快捷键映射
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "为不同文件类型和缓冲区类型设置快捷键映射",
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	callback = function()
		local buf_keymaps = require("utils.utils").buf_keymaps
		local current_type = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype

		if not buf_keymaps then
			return
		end

		-- 遍历所有按键配置
		for key, filetype_configs in pairs(buf_keymaps) do
			local command_config = filetype_configs[current_type]

			if command_config and command_config.cmd then
				local opts = { buffer = true, noremap = true, silent = true, nowait = true }

				if type(command_config.cmd) == "function" then
					vim.keymap.set("n", key, command_config.cmd, opts)
				else
					vim.keymap.set("n", key, function()
						vim.cmd(command_config.cmd)
					end, opts)
				end
			end
		end
	end,
})

-- =============================================
-- 剪贴板与寄存器增强
-- =============================================

-- 寄存器历史管理（保存最近 10 次 yank/delete 操作）
vim.cmd([[
function! YankShift()
  call setreg(0, getreg('"'))
  for i in range(9, 1, -1)
    call setreg(i, getreg(i - 1))
  endfor
endfunction

augroup YankHistory
  autocmd!
  au TextYankPost * if index(['y', 'd'], v:event.operator) >= 0 | call YankShift() | endif
augroup END
]])

-- 记录复制操作前的光标位置
local cursor_pre_yank = nil
vim.keymap.set({ "n", "x" }, "y", function()
	cursor_pre_yank = vim.api.nvim_win_get_cursor(0)
	return "y"
end, { expr = true })

vim.keymap.set("n", "Y", function()
	cursor_pre_yank = vim.api.nvim_win_get_cursor(0)
	return "y$"
end, { expr = true })

-- 复制操作后的处理：高亮、恢复光标、同步系统剪贴板
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("EnhancedYank", { clear = true }),
	desc = "复制后高亮文本、恢复光标位置并同步到系统剪贴板",
	callback = function()
		vim.highlight.on_yank({ timeout = 250 }) -- 高亮复制的文本

		local ev = vim.v.event
		-- 恢复复制前的光标位置
		if ev.operator == "y" and cursor_pre_yank then
			vim.schedule(function()
				pcall(vim.api.nvim_win_set_cursor, 0, cursor_pre_yank)
				cursor_pre_yank = nil
			end)
		end

		-- 同步到系统剪贴板
		if vim.fn.has("clipboard") == 1 then
			local clipboard_content = vim.fn.getreg('"')
			if clipboard_content ~= "" then
				-- 延迟同步系统剪贴板，避免阻塞
				vim.defer_fn(function()
					pcall(vim.fn.setreg, "+", clipboard_content)
				end, 80)
			end
		end
	end,
})

-- 从系统剪贴板同步到 Neovim
vim.api.nvim_create_autocmd("FocusGained", {
	group = vim.api.nvim_create_augroup("ClipboardSyncFocus", { clear = true }),
	desc = "窗口获得焦点时从系统剪贴板同步到 Neovim",
	callback = function()
		if vim.fn.has("clipboard") == 1 then
			vim.defer_fn(function()
				local system_content = vim.fn.getreg("+")
				-- 只在有内容且长度大于1时同步，避免同步单个字符
				if system_content and system_content ~= "" and #system_content > 1 then
					local current_content = vim.fn.getreg('"')
					-- 只在内容不同时同步，避免不必要的操作
					if system_content ~= current_content then
						vim.fn.setreg('"', system_content)
						vim.fn.setreg("0", system_content)
					end
				end
			end, 80)
		end
	end,
})

-- =============================================
-- Quickfix 和 Location List 增强
-- =============================================

-- 删除 quickfix 或 location list 项目的函数
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

-- 检查指定类型窗口是否已打开
local function is_window_open(win_type)
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win_type == "quickfix" and win.quickfix == 1 then
			return true
		elseif win_type == "loclist" and win.loclist == 1 then
			return true
		end
	end
	return false
end

-- Quickfix 和 Location List 窗口的增强设置
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("QuickfixTweaks", { clear = true }),
	pattern = "qf",
	desc = "Quickfix 和 Location List 窗口的快捷键和设置",
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

-- 创建切换 Quickfix/Location List 的用户命令
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
end, { desc = "切换 Quickfix 或 Location List 窗口", nargs = "?" })
