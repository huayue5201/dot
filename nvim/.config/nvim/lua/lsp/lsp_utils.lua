local M = {}

M.icons = {
	diagnostic = {
		ERROR = "󰅚 ",
		WARN = "󰀪 ",
		HINT = " ",
		INFO = " ",
	},
}

-- 缓存
M._lsp_config_cache = nil
M._filetype_index = nil

--------------------------------------------------------------
-- 配置验证
--------------------------------------------------------------
function M._validate_lsp_config(config, filename)
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
-- 加载配置
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
			local valid, err = M._validate_lsp_config(config, filename)
			if valid then
				configs[filename] = config
			else
				vim.notify(string.format("Invalid LSP config %s: %s", filename, err), vim.log.levels.ERROR)
			end
		else
			vim.notify("Failed to load config from: " .. path, vim.log.levels.ERROR)
		end
	end

	M._lsp_config_cache = configs
	return configs
end

--------------------------------------------------------------
-- 构建 filetype 索引
--------------------------------------------------------------
function M._build_filetype_index()
	if M._filetype_index then
		return M._filetype_index
	end

	local index = {}
	local configs = M._load_all_lsp_configs()

	for name, config in pairs(configs) do
		local fts = config.filetypes
		if fts then
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
-- 缓存控制
--------------------------------------------------------------
function M.clear_lsp_config_cache()
	M._lsp_config_cache = nil
	M._filetype_index = nil
end

function M.reload_lsp_configs()
	M.clear_lsp_config_cache()
	local count = 0
	for _ in pairs(M._load_all_lsp_configs()) do
		count = count + 1
	end
	return M._lsp_config_cache, count
end

--------------------------------------------------------------
-- 查询接口
--------------------------------------------------------------
function M.get_lsp_config(...)
	local fields = { ... }
	return M.get_lsp_config_with_opts({}, unpack(fields))
end

function M.get_lsp_config_with_opts(opts, ...)
	opts = opts or {}
	local quiet = opts.quiet or false
	local fields = { ... }

	local all_configs = M._load_all_lsp_configs()

	-- 无字段：返回完整配置
	if #fields == 0 then
		return all_configs
	end

	-- 单字段查询
	if #fields == 1 then
		local field = fields[1]
		local result = {}

		for filename, config in pairs(all_configs) do
			if field == "name" then
				table.insert(result, filename)
			else
				local value = config[field]
				if value then
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
				elseif not quiet then
					vim.notify("Field '" .. field .. "' not found in config: " .. filename, vim.log.levels.DEBUG)
				end
			end
		end

		return vim.fn.sort(result)
	end

	-- 多字段查询：独立字段
	local multi = {}
	for _, field in ipairs(fields) do
		multi[field] = M.get_lsp_config_with_opts({ quiet = quiet }, field)
	end
	return multi
end

--------------------------------------------------------------
-- 获取 LSP 名称
--------------------------------------------------------------
function M.get_lsp_name()
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = string.lower(vim.bo[bufnr].filetype)
	return M.get_lsp_by_filetype(ft)
end

function M.get_lsp_by_filetype(filetype)
	return (M._build_filetype_index())[string.lower(filetype)] or {}
end

function M.get_all_lsp_names()
	return M.get_lsp_config("name")
end

--------------------------------------------------------------
-- 活跃 LSP
--------------------------------------------------------------
function M.get_active_lsps(bufnr)
	bufnr = bufnr or 0
	local ok, clients = pcall(vim.lsp.get_clients, { bufnr = bufnr })

	if not ok or not clients then
		if not ok then
			vim.notify("Error getting LSP clients: " .. clients, vim.log.levels.ERROR)
		end
		return {}
	end

	local active = {}
	for _, client in pairs(clients) do
		table.insert(active, {
			id = client.id,
			name = client.name,
			root_dir = client.config.root_dir or "",
		})
	end
	return active
end

--------------------------------------------------------------
-- 自动重载配置
--------------------------------------------------------------
vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = { "*/lsp/*.lua", "lua/lsp/*.lua" },
	callback = function()
		local _, count = M.reload_lsp_configs()
		vim.notify(string.format("LSP configurations reloaded (%d configs)", count), vim.log.levels.INFO)
	end,
})

return M
