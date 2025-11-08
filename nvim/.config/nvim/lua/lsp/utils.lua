-- LSP 工具函数模块
-- 整合所有工具函数，包括 LSP 配置查询、功能支持检测等
local M = {}

-- 缓存管理
M._lsp_config_cache = nil
M._filetype_lsp_cache = nil

-- =============================================
-- LSP 配置管理
-- =============================================

-- 加载所有 LSP 配置
function M._load_all_lsp_configs()
	if M._lsp_config_cache then
		return M._lsp_config_cache
	end

	local configs = {}
	for _, path in ipairs(vim.api.nvim_get_runtime_file("after/lsp/*.lua", true)) do
		local filename = vim.fn.fnamemodify(path, ":t:r")
		local ok, config = pcall(dofile, path)
		if ok and type(config) == "table" then
			configs[filename] = config
		else
			vim.notify("加载配置失败: " .. path, vim.log.levels.ERROR)
		end
	end

	M._lsp_config_cache = configs
	return configs
end

-- 构建文件类型到 LSP 的映射缓存
function M._build_filetype_lsp_cache()
	local all_configs = M._load_all_lsp_configs()
	local cache = {}

	for lsp_name, config in pairs(all_configs) do
		if config.filetypes then
			local filetypes = type(config.filetypes) == "string" and { config.filetypes } or config.filetypes
			for _, ft in ipairs(filetypes) do
				ft = string.lower(ft)
				cache[ft] = cache[ft] or {}
				table.insert(cache[ft], lsp_name)
			end
		end
	end

	M._filetype_lsp_cache = cache
end

-- 检查配置是否匹配文件类型
function M._config_matches_filetype(config, filetype)
	if not config.filetypes then
		return false
	end

	local filetypes = config.filetypes
	if type(filetypes) == "string" then
		filetypes = { filetypes }
	end

	for _, ft in ipairs(filetypes) do
		if string.lower(ft) == filetype then
			return true
		end
	end
	return false
end

-- 获取 LSP 配置
function M.get_lsp_config(...)
	local fields = { ... }
	local all_configs = M._load_all_lsp_configs()

	if #fields == 0 then
		return all_configs
	end

	local result = {}
	for _, field in ipairs(fields) do
		if field == "name" then
			for filename in pairs(all_configs) do
				table.insert(result, filename)
			end
		else
			for _, config in pairs(all_configs) do
				if config[field] then
					local value = config[field]
					if type(value) == "table" then
						for _, v in ipairs(value) do
							if not vim.tbl_contains(result, v) then
								table.insert(result, v)
							end
						end
					else
						if not vim.tbl_contains(result, value) then
							table.insert(result, value)
						end
					end
				end
			end
		end
	end

	return result
end

-- 获取支持当前文件类型的 LSP 名称（使用缓存优化）
function M.get_lsp_name()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_filetype = string.lower(vim.bo[bufnr].filetype)

	-- 如果缓存不存在，则构建缓存
	if not M._filetype_lsp_cache then
		M._build_filetype_lsp_cache()
	end

	return M._filetype_lsp_cache[current_filetype] or {}
end

-- =============================================
-- LSP 客户端状态检查
-- =============================================

-- 获取当前缓冲区的活跃 LSP 客户端列表
function M.get_active_lsps(bufnr)
	bufnr = bufnr or 0
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	if not clients or vim.tbl_isempty(clients) then
		return {}
	end

	local active = {}
	for _, client in ipairs(clients) do
		table.insert(active, {
			id = client.id,
			name = client.name,
			root_dir = client.config.root_dir,
		})
	end
	return active
end

-- 获取所有 LSP 支持的文件类型列表（用于自动命令的 pattern）
function M.get_supported_filetypes()
	local all_configs = M._load_all_lsp_configs()
	local filetypes = {}

	for _, config in pairs(all_configs) do
		if config.filetypes then
			local ft_list = type(config.filetypes) == "string" and { config.filetypes } or config.filetypes
			for _, ft in ipairs(ft_list) do
				if not vim.tbl_contains(filetypes, ft) then
					table.insert(filetypes, ft)
				end
			end
		end
	end

	return filetypes
end

-- =============================================
-- LSP 功能支持检测
-- =============================================

-- 检查 LSP 客户端是否支持特定方法
function M.client_supports_method(client, method)
	if not client or not client.supports then
		return false
	end
	return client.supports(method)
end

-- 获取当前缓冲区的 LSP 功能支持状态
function M.get_buffer_capabilities(bufnr)
	bufnr = bufnr or 0
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	local capabilities = {}

	for _, client in ipairs(clients) do
		local caps = client.server_capabilities
		if caps then
			capabilities[client.name] = {
				document_formatting = not not caps.documentFormattingProvider,
				document_range_formatting = not not caps.documentRangeFormattingProvider,
				code_action = not not caps.codeActionProvider,
				completion = not not caps.completionProvider,
				hover = not not caps.hoverProvider,
				signature_help = not not caps.signatureHelpProvider,
				definition = not not caps.definitionProvider,
				references = not not caps.referencesProvider,
				implementation = not not caps.implementationProvider,
				rename = not not caps.renameProvider,
			}
		end
	end

	return capabilities
end

-- =============================================
-- 格式化功能
-- =============================================

-- 格式化当前缓冲区（使用支持格式化的第一个 LSP 客户端）
function M.format_buffer()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	for _, client in ipairs(clients) do
		if M.client_supports_method(client, "textDocument/formatting") then
			vim.lsp.buf.format({
				filter = function(c)
					return c.name == client.name
				end,
				async = false,
			})
			return true
		end
	end
	return false
end

-- =============================================
-- 诊断工具
-- =============================================

-- 获取当前行的诊断信息
function M.get_current_line_diagnostics()
	local row = unpack(vim.api.nvim_win_get_cursor(0)) - 1
	return vim.diagnostic.get(0, { lnum = row })
end

-- 检查当前行是否有错误
function M.has_error_on_current_line()
	local diags = M.get_current_line_diagnostics()
	for _, diag in ipairs(diags) do
		if diag.severity == vim.diagnostic.severity.ERROR then
			return true
		end
	end
	return false
end

return M
