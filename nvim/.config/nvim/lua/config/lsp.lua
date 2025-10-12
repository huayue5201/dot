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

-- 获取所有lsp配置
function M.get_lsp_config(...)
	local fields = { ... } -- 收集所有参数
	local result = {}
	-- 处理无参数情况：返回完整配置表
	if #fields == 0 then
		for _, path in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
			local filename = vim.fn.fnamemodify(path, ":t:r")
			local ok, config = pcall(dofile, path)
			if ok and type(config) == "table" then
				result[filename] = config
			else
				vim.notify("Failed to load config from: " .. path, vim.log.levels.ERROR)
			end
		end
		return result
	end
	-- 初始化结果结构
	local multi_result = {}
	local is_single_field = (#fields == 1)
	-- 为每个字段创建结果容器
	for _, field in ipairs(fields) do
		if is_single_field then
			result = {} -- 单参数时使用平面列表
		else
			multi_result[field] = {} -- 多参数时使用字段键值表
		end
	end
	-- 遍历所有配置文件
	for _, path in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
		local filename = vim.fn.fnamemodify(path, ":t:r")
		local ok, config = pcall(dofile, path)

		if ok and type(config) == "table" then
			for _, field in ipairs(fields) do
				-- 处理特殊字段 "name"
				if field == "name" then
					if is_single_field then
						table.insert(result, filename)
					else
						table.insert(multi_result[field], filename)
					end
				else
					-- 处理其他字段
					if config[field] then
						local value = config[field]
						-- 处理表值（合并）
						if type(value) == "table" then
							for _, v in ipairs(value) do
								local target = is_single_field and result or multi_result[field]
								if not vim.tbl_contains(target, v) then
									table.insert(target, v)
								end
							end
						-- 处理非表值（确保唯一性）
						else
							local target = is_single_field and result or multi_result[field]
							if not vim.tbl_contains(target, value) then
								table.insert(target, value)
							end
						end
					else
						-- 字段不存在时发出警告
						vim.notify("Field '" .. field .. "' not found in config: " .. path, vim.log.levels.WARN)
					end
				end
			end
		else
			vim.notify("Failed to load config from: " .. path, vim.log.levels.ERROR)
		end
	end
	-- 返回结果
	return is_single_field and result or multi_result
end

-- 获取支持当前文件类型的 LSP 名称列表
function M.get_lsp_name()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_filetype = vim.bo[bufnr].filetype
	current_filetype = string.lower(current_filetype)

	local all_configs = M.get_lsp_config() -- 获取所有 LSP 配置
	local matched_lsp_names = {}

	for lsp_name, config in pairs(all_configs) do
		local filetypes = config.filetypes
		if filetypes then
			-- 处理字符串类型的 filetypes
			if type(filetypes) == "string" then
				filetypes = { filetypes }
			end
			-- 检查当前文件类型是否在配置中
			for _, ft in ipairs(filetypes) do
				if string.lower(ft) == current_filetype then
					table.insert(matched_lsp_names, lsp_name)
					break -- 找到匹配后跳出内层循环
				end
			end
		end
	end

	return matched_lsp_names
end

-- 重启当前缓冲区的 LSP 客户端
function M.restart_lsp()
	vim.lsp.stop_client(vim.lsp.get_clients(), true)
	-- 延迟启动 LSP
	vim.defer_fn(function()
		local lsp_name = M.get_lsp_name()

		vim.lsp.enable(lsp_name, true)
		-- 更新 LSP 状态
		require("utils.project_lsp_toggle").set_lsp_state(true)
	end, 500)
end

-- 关闭lsp
function M.stop_lsp()
	vim.lsp.stop_client(vim.lsp.get_clients(), true)
	require("utils.project_lsp_toggle").set_lsp_state(false)
	vim.schedule(function()
		vim.cmd.redrawstatus()
	end)
end

return M
