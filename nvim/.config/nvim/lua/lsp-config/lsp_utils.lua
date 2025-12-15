local M = {}

M.icons = {
	diagnostic = {
		ERROR = "󰅚 ",
		WARN = "󰀪 ",
		HINT = " ",
		INFO = " ",
	},
}

-- 缓存系统
M._lsp_config_cache = nil
M._filetype_index = nil

--------------------------------------------------------------
-- 配置验证 (移除了未使用的filename参数)
--------------------------------------------------------------
function M._validate_lsp_config(config)
	if type(config) ~= "table" then
		return false, "Config must be a table"
	end

	if not config.cmd and not config.setup then
		return false, "Config must have 'cmd' or 'setup' function"
	end

	if config.setup and type(config.setup) ~= "function" then
		return false, "'setup' must be a function"
	end

	if config.filetypes then
		local ft_type = type(config.filetypes)
		if ft_type ~= "string" and ft_type ~= "table" then
			return false, "filetypes must be string or table"
		end

		if ft_type == "table" then
			for _, ft in ipairs(config.filetypes) do
				if type(ft) ~= "string" then
					return false, "filetypes table must only contain strings"
				end
			end
		end
	end

	return true
end

--------------------------------------------------------------
-- 加载配置 (核心缓存)
--------------------------------------------------------------
function M._load_all_lsp_configs()
	if M._lsp_config_cache then
		return M._lsp_config_cache
	end

	local configs = {}
	for _, path in ipairs(vim.api.nvim_get_runtime_file("lsp/*.lua", true)) do
		local filename = vim.fn.fnamemodify(path, ":t:r")
		local ok, config = pcall(dofile, path)

		if ok and type(config) == "table" then
			local valid, err = M._validate_lsp_config(config)
			if valid then
				configs[filename] = config
			else
				vim.notify(string.format("Invalid LSP config %s: %s", filename, err), vim.log.levels.WARN)
			end
		else
			vim.notify("Failed to load config from: " .. path, vim.log.levels.WARN)
		end
	end

	M._lsp_config_cache = configs
	return configs
end

--------------------------------------------------------------
-- 构建 filetype 索引 (作为主缓存的派生缓存)
--------------------------------------------------------------
function M._build_filetype_index()
	if M._filetype_index then
		return M._filetype_index
	end

	local configs = M.reload_lsp_configs() -- 保证最新
	local index = {}

	for name, config in pairs(configs) do
		local fts = config.filetypes
		if fts == nil then
			-- 表示全局适用，不需要特殊 key，直接在查询时处理
			config._global = true
		else
			if type(fts) == "string" then
				fts = { fts }
			end
			for _, ft in ipairs(fts) do
				ft = string.lower(ft)
				index[ft] = index[ft] or {}
				if not vim.tbl_contains(index[ft], name) then
					table.insert(index[ft], name)
				end
			end
		end
	end

	M._filetype_index = index
	return index
end

--------------------------------------------------------------
-- 缓存控制 (保持一致性)
--------------------------------------------------------------
function M.clear_lsp_config_cache()
	M._lsp_config_cache = nil
	M._filetype_index = nil
end

function M.reload_lsp_configs()
	M.clear_lsp_config_cache()
	local configs = M._load_all_lsp_configs()
	return configs, vim.tbl_count(configs)
end

--------------------------------------------------------------
-- 查询接口优化
--------------------------------------------------------------

-- 优化的字段值提取器
function M._extract_field_value(config, field, filename, quiet)
	if field == "name" then
		-- 优先使用配置中的name字段，其次使用文件名
		return config.name or filename
	end

	local value = config[field]
	if value == nil and not quiet then
		vim.notify("Field '" .. field .. "' not found in config: " .. filename, vim.log.levels.DEBUG)
	end
	return value
end

-- 统一的值处理器 (处理数组和标量)
function M._process_value_into_results(value, results)
	local function add_item(item)
		if not vim.tbl_contains(results, item) then
			table.insert(results, item)
		end
	end

	if type(value) == "table" then
		for _, v in ipairs(value) do
			add_item(v)
		end
	else
		add_item(value)
	end
end

-- 单字段查询
function M._query_single_field(all_configs, field, quiet)
	local results = {}

	for filename, config in pairs(all_configs) do
		local value = M._extract_field_value(config, field, filename, quiet)
		if value ~= nil then
			M._process_value_into_results(value, results)
		end
	end

	return vim.fn.sort(results)
end

-- 多字段查询 (返回扁平表)
function M._query_multiple_fields(all_configs, fields, quiet)
	local multi_results = {}

	for _, field in ipairs(fields) do
		multi_results[field] = M._query_single_field(all_configs, field, quiet)
	end

	return multi_results
end

-- 主查询函数 - 简化接口
function M.get_lsp_config(...)
	local fields = { ... }

	-- 如果没有参数，返回完整配置
	if #fields == 0 then
		return M._load_all_lsp_configs()
	end

	local all_configs = M._load_all_lsp_configs()

	-- 单字段查询：直接返回数组
	if #fields == 1 then
		return M._query_single_field(all_configs, fields[1], false)
	end

	-- 多字段查询：返回 {field=结果} 表
	return M._query_multiple_fields(all_configs, fields, false)
end

-- 带选项的查询函数
function M.get_lsp_config_with_opts(opts, ...)
	opts = vim.tbl_extend("force", { quiet = false }, opts or {})
	local fields = { ... }

	if #fields == 0 then
		return M._load_all_lsp_configs()
	end

	local all_configs = M._load_all_lsp_configs()

	if #fields == 1 then
		return M._query_single_field(all_configs, fields[1], opts.quiet)
	end

	return M._query_multiple_fields(all_configs, fields, opts.quiet)
end

--------------------------------------------------------------
-- 获取 LSP 名称 (核心功能)
--------------------------------------------------------------
function M.get_lsp_name()
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = string.lower(vim.bo[bufnr].filetype)
	return M.get_lsp_by_filetype(ft)
end

function M.get_lsp_by_filetype(filetype)
	local index = M._build_filetype_index()
	local results = vim.deepcopy(index[string.lower(filetype)] or {})

	-- 合并所有 filetypes = nil 的配置
	for name, config in pairs(M._load_all_lsp_configs()) do
		if config.filetypes == nil and not vim.tbl_contains(results, name) then
			table.insert(results, name)
		end
	end

	return results
end

function M.get_all_lsp_names()
	return M.get_lsp_config("name")
end

--------------------------------------------------------------
-- 活跃 LSP 查询
--------------------------------------------------------------
function M.get_active_lsps(bufnr)
	bufnr = bufnr or 0
	local ok, clients = pcall(vim.lsp.get_clients, { bufnr = bufnr })

	if not ok or not clients then
		if not ok then
			vim.notify("Error getting LSP clients: " .. tostring(clients), vim.log.levels.ERROR)
		end
		return {}
	end

	local active = {}
	for _, client in ipairs(clients) do
		table.insert(active, {
			id = client.id,
			name = client.name,
			root_dir = client.config.root_dir or "",
		})
	end
	return active
end

--------------------------------------------------------------
-- 自动重载配置 (优化监控模式)
--------------------------------------------------------------
vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = { "lsp/*.lua", "after/lsp/*.lua" },
	callback = function(args)
		-- 只重载与当前文件相关的配置
		local filename = vim.fn.fnamemodify(args.file, ":t:r")
		local _, count = M.reload_lsp_configs()
		vim.notify(string.format("LSP configurations reloaded (%d configs total)", count), vim.log.levels.INFO)
	end,
	group = vim.api.nvim_create_augroup("LSPConfigAutoReload", { clear = true }),
})

return M
