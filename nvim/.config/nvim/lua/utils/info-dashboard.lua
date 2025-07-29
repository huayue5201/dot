local M = {}

local function get_lsp_name()
	-- 获取当前文件类型
	local filetype = vim.bo.filetype
	-- 获取所有的 LSP 配置
	local lsp_configs = require("config.lsp").get_lsp_config()
	-- 遍历所有 LSP 配置
	for lsp_name, config in pairs(lsp_configs) do
		-- 如果当前文件类型在 LSP 配置的 filetypes 中
		if vim.tbl_contains(config.filetypes, filetype) then
			return lsp_name -- 返回匹配的 LSP 名称
		end
	end
	-- 如果没有找到匹配的 LSP，则返回 "Unknown LSP"
	return "Unknown LSP"
end

local function get_lsp_info()
	local lsp_name = get_lsp_name()
	local is_lsp_enabled = require("utils.project_lsp_toggle").get_lsp_state() -- 确保正确导入状态管理模块
	return "LSP: " .. lsp_name .. (is_lsp_enabled and " 🟢" or " 🔴")
end

-- 获取文件类型的函数
local function get_file_type()
	return "File Type: " .. vim.bo.filetype
end

-- 获取 Linter 状态的函数
local function get_lint_info()
	local ok, lint = pcall(require, "lint")
	if not ok then
		return "Linting: Not available"
	end

	local linters = lint.get_running()
	if #linters == 0 then
		return "Linting: Inactive"
	end
	return "Linting: " .. table.concat(linters, ", ")
end

local function get_elements()
	local elements = {
		get_file_type(),
		get_lsp_info(),
		get_lint_info(),
	}

	-- 插入空行与空格
	local formatted_elements = {}
	for _, element in ipairs(elements) do
		table.insert(formatted_elements, " " .. element) -- 添加空格
		table.insert(formatted_elements, "") -- 添加空行
	end

	-- 最后返回拼接后的字符串，去掉末尾的多余空行
	return formatted_elements
end

-- 创建并显示浮动窗口
function M.show_statusboard()
	local content = get_elements()

	-- 计算窗口宽度（基于最长行）
	local max_width = 0
	for _, line in ipairs(content) do
		max_width = math.max(max_width, #line)
	end
	max_width = math.min(max_width + 4, vim.o.columns - 10) -- 限制最大宽度

	-- 创建浮动窗口配置
	local opts = {
		relative = "editor",
		width = max_width,
		height = #content - 1,
		col = math.floor((vim.o.columns - max_width) / 2),
		row = math.floor((vim.o.lines - (#content + 2)) / 2),
		title = " Info ",
		title_pos = "center",
		style = "minimal",
		border = "rounded",
	}

	-- 创建缓冲区和窗口
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

	-- 创建窗口
	local win = vim.api.nvim_open_win(buf, true, opts)

	-- 设置窗口只读
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- 设置窗口高亮和焦点
	vim.api.nvim_set_option_value("winhl", "Normal:NormalFloat", { win = win })
	vim.api.nvim_set_option_value("winblend", 30, { win = win })

	-- 添加退出键映射
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<cmd>q<cr>", { silent = true, nowait = true })
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>q<cr>", { silent = true, nowait = true })

	-- 记录窗口，用于自动关闭
	M.status_window = win

	-- 自动关闭功能
	vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
		callback = function()
			if M.status_window and vim.api.nvim_win_is_valid(M.status_window) then
				vim.api.nvim_win_close(M.status_window, true)
				M.status_window = nil
			end
		end,
	})

	-- 强制刷新高亮
	vim.cmd("redraw")
end

-- 创建命令以便快速调用状态看板
vim.api.nvim_create_user_command("StatusInfo", M.show_statusboard, {})

return M
