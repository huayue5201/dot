local M = {}

-- 缓存 LSP 配置，避免重复加载
M._lsp_config_cache = nil

-- 内部函数：加载所有 LSP 配置
function M._load_all_lsp_configs()
	if M._lsp_config_cache then
		return M._lsp_config_cache
	end
	local configs = {}
	for _, path in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
		local filename = vim.fn.fnamemodify(path, ":t:r")
		local ok, config = pcall(dofile, path)
		if ok and type(config) == "table" then
			configs[filename] = config
		else
			vim.notify("Failed to load config from: " .. path, vim.log.levels.ERROR)
		end
	end
	M._lsp_config_cache = configs
	return configs
end

-- 清空缓存（在配置重载时调用）
function M.clear_lsp_config_cache()
	M._lsp_config_cache = nil
end

-- 内部函数：检查配置是否匹配文件类型
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

-- 通用 LSP 配置查询函数
function M.get_lsp_config(...)
	local fields = { ... }
	local all_configs = M._load_all_lsp_configs()
	local result = {}
	-- 处理无参数情况：返回完整配置表
	if #fields == 0 then
		return all_configs
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
	for filename, config in pairs(all_configs) do
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
					vim.notify("Field '" .. field .. "' not found in config: " .. filename, vim.log.levels.WARN)
				end
			end
		end
	end
	-- 返回结果
	return is_single_field and result or multi_result
end

-- 获取支持当前文件类型的 LSP 名称列表
function M.get_lsp_name()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_filetype = string.lower(vim.bo[bufnr].filetype)

	local all_configs = M._load_all_lsp_configs()
	local matched_lsp_names = {}

	for lsp_name, config in pairs(all_configs) do
		if M._config_matches_filetype(config, current_filetype) then
			table.insert(matched_lsp_names, lsp_name)
		end
	end

	return matched_lsp_names
end

-- 可选：获取指定文件类型的 LSP 名称
function M.get_lsp_by_filetype(filetype)
	filetype = string.lower(filetype)
	local all_configs = M._load_all_lsp_configs()
	local matched_lsp_names = {}
	for lsp_name, config in pairs(all_configs) do
		if M._config_matches_filetype(config, filetype) then
			table.insert(matched_lsp_names, lsp_name)
		end
	end

	return matched_lsp_names
end
-- 可选：获取所有 LSP 名称（快捷方式）
function M.get_all_lsp_names()
	return M.get_lsp_config("name")
end

-- 查看当前 buffer 的活跃 LSP
function M.get_active_lsps(bufnr)
	bufnr = bufnr or 0
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	if not clients or vim.tbl_isempty(clients) then
		vim.notify("No active LSP clients for this buffer.", vim.log.levels.WARN)
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

return M
