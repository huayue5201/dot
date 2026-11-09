-- https://github.com/sqls-server/sqls
-- 安装：go install github.com/sqls-server/sqls@latest
--   （旧仓库 lighttiger2505/sqls 已迁到 sqls-server/sqls；brew 没有这个 formula）
--
-- 连接配置的三条路：
--   1) initialize 的 initializationOptions.connectionConfig（最高优先级，本文件用这条）
--   2) workspace/didChangeConfiguration 推 settings.sqls
--   3) ~/.config/sqls/config.yml（全局，没有「项目内 .sqls.yml 自动发现」）
-- 这里在 before_init 里按项目根找本地 sqlite 文件，动态填 initializationOptions，
-- 避免把某个项目的绝对路径写死进全局配置。
--
-- 与现有工具的边界：
--   * 格式化 → conform 的 sqlfluff；关掉 sqls 的 formatting，避免 sqlfmt/sqlfluff 互改
--   * 语法 lint → nvim-lint 的 sqlfluff --rules=PRS；sqls 诊断保留（它额外报未知表/未知列）
--
-- 库位置与 date_pulse 的 src/db.rs `default_db_path()` 保持一致：
--   DATA_PULSE_DB > $XDG_DATA_HOME/data_pulse/date_pulse.db > <root>/data/*.db
local function is_db_file(name)
	return name:match("%.db$") ~= nil or name:match("%.sqlite3?$") ~= nil
end

local function find_sqlite(root)
	local env_db = vim.env.DATA_PULSE_DB
	if env_db and env_db ~= "" and vim.uv.fs_stat(env_db) then
		return env_db
	end

	local data_home = vim.env.XDG_DATA_HOME
	if not data_home or data_home == "" then
		local home = vim.env.HOME
		data_home = home and (home .. "/.local/share") or nil
	end
	if data_home then
		local xdg_db = data_home .. "/data_pulse/date_pulse.db"
		if vim.uv.fs_stat(xdg_db) then
			return xdg_db
		end
	end

	for _, dir in ipairs({ root .. "/data", root .. "/db", root }) do
		local stat = vim.uv.fs_stat(dir)
		if stat and stat.type == "directory" then
			local hit = vim.fs.find(is_db_file, { path = dir, type = "file", limit = 1 })
			if hit[1] then
				return hit[1]
			end
		end
	end
end

return {
	cmd = { "sqls" },
	filetypes = { "sql" },
	root_markers = { ".git" },
	before_init = function(params, config)
		local root = config.root_dir
		local db = root and find_sqlite(root)
		if not db then
			return
		end
		params.initializationOptions = vim.tbl_deep_extend("force", params.initializationOptions or {}, {
			connectionConfig = { alias = "project", driver = "sqlite3", dataSourceName = db },
		})
	end,
	on_init = function(client)
		-- 格式化交给 conform/sqlfluff
		client.server_capabilities.documentFormattingProvider = false
		client.server_capabilities.documentRangeFormattingProvider = false
	end,
}
