local M = {}

local lint = require("lint")

-- 获取当前 LSP 客户端信息
local function get_lsp_info()
	local buf_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })
	if vim.tbl_isempty(buf_clients) then
		return "No LSP clients connected"
	end

	local client_info = {}
	for _, client in ipairs(buf_clients) do
		table.insert(client_info, client.name)
	end

	return "LSP Clients: " .. table.concat(client_info, ", ")
end

-- 获取当前文件类型
local function get_file_type()
	return "File Type: " .. vim.bo.filetype
end

-- 获取 Linter 状态
local function get_lint_info()
	local linters = lint.get_running()
	if #linters == 0 then
		return "No Linting"
	end
	return "Linting: " .. table.concat(linters, ", ")
end

-- 创建浮动窗口显示 LSP、文件类型和 Lint 状态
function M.show_statusboard()
	local lsp_info = get_lsp_info()
	local file_type = get_file_type()
	local lint_info = get_lint_info()

	-- 设置窗口内容
	local content = {
		lsp_info,
		"",
		file_type,
		"",
		lint_info,
	}

	-- 创建浮动窗口
	local opts = {
		relative = "editor",
		width = 50,
		height = #content + 2,
		col = math.floor((vim.o.columns - 50) / 2),
		row = math.floor((vim.o.lines - (#content + 2)) / 2),
		title = "neovim状态",
		title_pos = "center",
		style = "minimal",
		border = "rounded",
	}

	-- 打开浮动窗口并显示内容
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
	vim.api.nvim_open_win(buf, true, opts)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf }) -- 窗口只读
end

-- 创建命令以便快速调用状态看板
vim.api.nvim_create_user_command("ListInfo", M.show_statusboard, {})

return M
