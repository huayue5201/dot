-- json_store/core/project.lua
local config = require("json_store.core.config")

local M = {}

local _projects = {}
local _global_project = nil

local function join(...)
	return table.concat({ ... }, "/")
end

local function sha256(str)
	return vim.fn.sha256(str)
end

local function file_exists(path)
	return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

-- 查找项目根目录
function M.find_project_root(filepath)
	local cfg = config.get()
	filepath = filepath or vim.api.nvim_buf_get_name(0)

	if filepath == "" then
		return vim.loop.cwd()
	end

	local dir = vim.fn.fnamemodify(filepath, ":p:h")
	local prev = nil

	while dir and dir ~= prev do
		for _, marker in ipairs(cfg.root_markers) do
			if file_exists(join(dir, marker)) then
				return dir
			end
		end
		prev = dir
		dir = vim.fn.fnamemodify(dir, ":h")
	end

	return vim.loop.cwd()
end

-- 生成 project_key
local function get_project_key(root)
	local name = vim.fn.fnamemodify(root, ":t")
	local hash = sha256(root):sub(1, 8)
	return (name .. "_" .. hash):gsub("[^%w_%-]", "_")
end

-- 创建或获取项目
function M.ensure_project(root, is_global)
	local cfg = config.get()

	if is_global then
		if _global_project then
			return "global", _global_project
		end

		local base = join(cfg.cache_root, "global")
		vim.fn.mkdir(base, "p")

		_global_project = {
			root = "global",
			key = "global",
			base = base,
			paths = {
				project = join(base, "project.json"),
				namespaces_dir = join(base, "namespaces"),
				files_dir = join(base, "files"),
			},
			stores = {
				project = nil,
				namespaces = {},
				files = {},
			},
			last_access = os.time(),
			is_global = true,
		}

		vim.fn.mkdir(_global_project.paths.namespaces_dir, "p")
		vim.fn.mkdir(_global_project.paths.files_dir, "p")

		return "global", _global_project
	end

	local key = get_project_key(root)
	if _projects[key] then
		_projects[key].last_access = os.time()
		return key, _projects[key]
	end

	local base = join(cfg.cache_root, key)
	vim.fn.mkdir(base, "p")

	local project = {
		root = root,
		key = key,
		base = base,
		paths = {
			project = join(base, "project.json"),
			namespaces_dir = join(base, "namespaces"),
			files_dir = join(base, "files"),
		},
		stores = {
			project = nil,
			namespaces = {},
			files = {},
		},
		last_access = os.time(),
		is_global = false,
	}

	vim.fn.mkdir(project.paths.namespaces_dir, "p")
	vim.fn.mkdir(project.paths.files_dir, "p")

	_projects[key] = project
	return key, project
end

function M.get_current_project()
	local root = M.find_project_root()
	local key, project = M.ensure_project(root)
	return key, project
end

function M.get_all_projects()
	return _projects
end

function M.get_global_project()
	return _global_project
end

-- 写入单个 project 的所有 store
function M.flush_project(project_obj)
	if not project_obj or not project_obj.stores then
		return
	end

	local store_mod = require("json_store.core.store")

	-- project.json
	if project_obj.stores.project then
		store_mod.write(project_obj.stores.project)
	end

	-- namespaces
	for _, ns_store in pairs(project_obj.stores.namespaces or {}) do
		store_mod.write(ns_store)
	end

	-- files
	for _, file_store in pairs(project_obj.stores.files or {}) do
		store_mod.write(file_store)
	end
end

-- 写入所有项目（包括 global）
function M.flush_all_projects()
	local store_mod = require("json_store.core.store")

	-- global
	local _, global_project = M.ensure_project("global", true)
	M.flush_project(global_project)

	-- normal projects
	for _, proj in pairs(_projects) do
		M.flush_project(proj)
	end
end

-- 可选：暴露内部表（如果你想调试方便）
M._projects = _projects
M._global_project = _global_project

return M
