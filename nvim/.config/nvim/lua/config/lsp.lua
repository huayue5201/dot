-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

-- LSP 配置模块
local M = {}

-- 设置诊断的全局配置
local icons = require("utils.utils").icons.diagnostic
M.diagnostic_config = function()
	vim.diagnostic.config({
		virtual_text = {
			current_line = false,
		},
		virtual_lines = {
			current_line = true,
		},
		severity_sort = true,
		-- float = { source = "if_many", border = "shadow" },
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = icons.ERROR,
				[vim.diagnostic.severity.WARN] = icons.WARN,
				[vim.diagnostic.severity.HINT] = icons.HINT,
				[vim.diagnostic.severity.INFO] = icons.INFO,
			},
			linehl = { [vim.diagnostic.severity.ERROR] = "ErrorMsg" },
			numhl = { [vim.diagnostic.severity.WARN] = "WarningMsg" },
		},
		underline = true,
		update_in_insert = true,
	})
end

-- 插入/选择模式禁用/启用诊断
M.mode_changed_handler = function()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s", "i:n" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			local diag_enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })
			if diag_enabled then
				-- 进入插入/选择模式时关闭诊断
				vim.diagnostic.enable(false, { bufnr = bufnr })
				-- 离开插入/选择模式后重新启用诊断，只启用一次自动命令
				vim.api.nvim_create_autocmd("ModeChanged", {
					pattern = { "i:n", "s:v" },
					once = true,
					desc = "离开插入/选择模式后重新启用诊断",
					callback = function()
						local current_buf = vim.api.nvim_get_current_buf()
						if vim.api.nvim_buf_is_valid(current_buf) then
							vim.diagnostic.enable(true, { bufnr = current_buf })
						end
					end,
				})
			end
		end,
	})
end

-- 插入模式下禁用内联提示，离开插入模式重新启用
M.inlay_hint_handler = function()
	vim.api.nvim_create_autocmd("InsertEnter", {
		desc = "Disable lsp.inlay_hint when in insert mode",
		callback = function(args)
			local filter = { bufnr = args.buf }
			local inlay_hint = vim.lsp.inlay_hint
			if inlay_hint.is_enabled(filter) then
				inlay_hint.enable(false, filter)
				vim.api.nvim_create_autocmd("InsertLeave", {
					once = true,
					desc = "Re-enable lsp.inlay_hint when leaving insert mode",
					callback = function()
						inlay_hint.enable(true, filter)
					end,
				})
			end
		end,
	})
end

-- 按键映射
local keymaps = {
	-- { "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },
	{
		"<leader>lw",
		"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
		"列出工作区文件夹",
	},
	{
		"<leader>toi",
		"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
		"打开/关闭内联提示",
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

function M.lint()
	require("lint").linters_by_ft = {
		-- https://github.com/danmar/cppcheck/
		c = { "cppcheck" },
	}

	M.diagnostic_config()

	vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
		callback = function()
			require("lint").try_lint()
		end,
	})
end

-- 打开所有 buffer 的诊断（Quickfix 风格，适合全局排查）
function M.open_all_diagnostics()
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

-- 复制光标处的错误信息（包括错误代码）
function M.CopyErrorMessage()
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

-- 仅当前 buffer 的诊断（Loclist 风格，适合局部修复）
function M.open_buffer_diagnostics()
	vim.diagnostic.setloclist({
		open = true,
		title = "Buffer Diagnostics",
		severity = { min = vim.diagnostic.severity.HINT },
		format = function(d)
			return string.format("[%s] %s (%s)", vim.diagnostic.severity[d.severity], d.message, d.source or "?")
		end,
	})
end

function M.get_lsp_config(field)
	local result = {}
	-- 获取所有 lsp/*.lua 文件的路径
	for _, path in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
		-- 获取文件名并去掉扩展名
		local filename = vim.fn.fnamemodify(path, ":t:r")
		-- 安全加载每个 LSP 配置文件
		local ok, config = pcall(dofile, path)
		if ok and type(config) == "table" then
			-- 处理无参数情况 - 返回完整配置表
			if not field then
				result[filename] = config
			-- 处理 "name" 参数 - 返回文件名列表
			elseif field == "name" then
				table.insert(result, filename)
			-- 处理其他字段
			else
				-- 如果字段存在，返回该字段的值
				if config[field] then
					if type(config[field]) == "table" then
						-- 合并表值
						for _, v in ipairs(config[field]) do
							if not vim.tbl_contains(result, v) then
								table.insert(result, v)
							end
						end
					else
						-- 添加非表值（确保唯一性）
						local value = config[field]
						if not vim.tbl_contains(result, value) then
							table.insert(result, value)
						end
					end
				else
					-- 如果字段不存在，给出警告信息
					vim.notify("Field '" .. field .. "' not found in config: " .. path, vim.log.levels.WARN)
				end
			end
		else
			-- 加载配置文件失败时的错误信息
			vim.notify("Failed to load config from: " .. path, vim.log.levels.ERROR)
		end
	end
	-- 根据参数类型返回不同的结果
	if not field then
		-- 无参数：返回完整配置表 {filename = config}
		return result
	elseif field == "name" then
		-- "name" 参数：返回文件名列表
		return result
	else
		-- 其他字段参数：返回字段值列表
		return result
	end
end

-- 重启当前缓冲区的 LSP 客户端
function M.restart_lsp()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
	-- 将 current_filetype 转换为小写，以防大小写不匹配
	current_filetype = string.lower(current_filetype)
	-- 获取所有 LSP 配置的 filetypes 字段
	local all_filetypes = M.get_lsp_config("filetypes")
	-- 检查当前文件类型是否在所有 LSP 配置的 filetypes 中
	local valid_lsp_found = false
	-- 使用 vim.fn.index 检查当前文件类型是否在 filetypes 数组中
	if vim.fn.index(all_filetypes, current_filetype) ~= -1 then
		valid_lsp_found = true
	end
	-- 如果找到匹配的 LSP 配置文件类型，则重启 LSP 客户端
	if valid_lsp_found then
		local clients = vim.lsp.get_clients({ bufnr = bufnr })
		-- 停止现有客户端
		for _, client in ipairs(clients) do
			vim.lsp.stop_client(client.id)
		end
		-- 启动 LSP
		vim.defer_fn(function()
			vim.lsp.enable(M.get_lsp_config("name"))
			require("utils.project_lsp_toggle").set_lsp_state(true)
		end, 100)
	else
		vim.notify("No LSP found for current filetype: " .. current_filetype)
	end
end

-- 关闭lsp
function M.stop_lsp()
	vim.lsp.stop_client(vim.lsp.get_clients(), true)
	require("utils.project_lsp_toggle").set_lsp_state(false)
	M.lint()
	vim.schedule(function()
		vim.cmd.redrawstatus()
	end)
end

return M
