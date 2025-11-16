local M = {}

-- 打开所有 buffer 的诊断（Quickfix 风格，适合全局排查）
local function open_all_diagnostics()
	---@diagnostic disable-next-line: param-type-mismatch
	vim.diagnostic.setqflist({
		open = true,
		title = "Project Diagnostics",
		severity = { min = vim.diagnostic.severity.WARN },
		format = function(d)
			return string.format(
				"[%s] %s (%s:%d)",
				vim.diagnostic.severity[d.severity],
				d.message,
				d.source or "?",
				d.lnum + 1
			)
		end,
	})
end

-- 仅当前 buffer 的诊断（Loclist 风格，适合局部修复）
local function open_buffer_diagnostics()
	---@diagnostic disable-next-line: param-type-mismatch
	vim.diagnostic.setloclist({
		open = true,
		title = "Buffer Diagnostics",
		severity = { min = vim.diagnostic.severity.HINT },
		format = function(d)
			return string.format("[%s] %s (%s)", vim.diagnostic.severity[d.severity], d.message, d.source or "?")
		end,
	})
end

-- 复制光标处的错误信息（包括错误代码）
local function CopyErrorMessage()
	local row = unpack(vim.api.nvim_win_get_cursor(0)) - 1
	local diag = vim.diagnostic.get(0, { lnum = row })
	if #diag > 0 then
		local messages = {}
		for _, diagnostic in ipairs(diag) do
			local code = diagnostic.code or "No code available"
			local message = diagnostic.message or "No message available"
			table.insert(messages, message .. " [" .. code .. "]")
		end
		local all_messages = table.concat(messages, "\n")
		vim.fn.setreg("+", all_messages)
		print("Error messages copied to clipboard:\n" .. all_messages)
	else
		print("No error at the cursor!")
	end
end

-- 按键映射
local keymaps = {
	-- { "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },
	{
		"<leader>ld",
		function()
			open_buffer_diagnostics()
		end,
		"当前buffer内诊断",
	},
	{
		"<leader>lD",
		function()
			open_all_diagnostics()
		end,
		"项目内所有诊断",
	},
	{
		"<leader>yd",
		function()
			CopyErrorMessage()
		end,
		"复制报错",
	},
	{
		"<localleader>li",
		"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
		"打开/关闭内联提示",
	},
	{
		"<leader>lw",
		"<cmd>LspListActive<cr>",
		"列出工作区文件夹",
	},
}

-- 设置按键映射
M.set_keymaps = function(bufnr)
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], { noremap = true, silent = true, desc = map[3], buffer = bufnr })
	end
end

-- 删除按键映射
M.remove_keymaps = function(bufnr)
	for _, map in ipairs(keymaps) do
		pcall(vim.keymap.del, "n", map[1], { buffer = bufnr })
	end
end

return M
