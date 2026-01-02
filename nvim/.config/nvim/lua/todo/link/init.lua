-- lua/todo/link/init.lua
local M = {}

-- 默认配置
local default_config = {
	jump = {
		keep_todo_split_when_jump = false, -- 分屏TODO跳转时是否保持分屏窗口
		default_todo_window_mode = "float", -- 默认打开TODO的窗口模式: "float" | "split" | "vsplit"
		reuse_existing_windows = true, -- 是否复用已存在的窗口
	},
	preview = {
		enabled = true, -- 是否启用预览功能
		border = "rounded", -- 预览窗口边框样式
	},
	render = {
		show_status_in_code = true, -- 在代码中显示TODO状态
		status_icons = { -- 状态图标
			todo = "☐",
			done = "✓",
		},
	},
}

-- 当前配置
local config = vim.deepcopy(default_config)

-- 延迟加载子模块
local modules = {
	utils = nil,
	creator = nil,
	jumper = nil,
	renderer = nil,
	syncer = nil,
	preview = nil,
	cleaner = nil,
	searcher = nil,
}

-- 动态获取模块
local function get_module(name)
	if not modules[name] then
		modules[name] = require("todo.link." .. name)
	end
	return modules[name]
end

---------------------------------------------------------------------
-- 配置管理
---------------------------------------------------------------------

-- 设置配置
function M.setup(user_config)
	if user_config then
		config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), user_config)
	end
end

-- 获取配置
function M.get_config()
	return vim.deepcopy(config)
end

-- 更新特定配置项
function M.update_config(key, value)
	local keys = vim.split(key, ".", { plain = true })
	local target = config

	for i = 1, #keys - 1 do
		local k = keys[i]
		if not target[k] then
			target[k] = {}
		end
		target = target[k]
	end

	target[keys[#keys]] = value
end

---------------------------------------------------------------------
-- 公开 API（保持与原 link.lua 相同）
---------------------------------------------------------------------

-- 链接创建
function M.create_link()
	return get_module("creator").create_link()
end

-- 链接跳转
function M.jump_to_todo()
	return get_module("jumper").jump_to_todo()
end

function M.jump_to_code()
	return get_module("jumper").jump_to_code()
end

function M.jump_dynamic()
	return get_module("jumper").jump_dynamic()
end

-- 状态渲染
function M.render_code_status(bufnr)
	return get_module("renderer").render_code_status(bufnr)
end

-- 同步管理
function M.sync_code_links()
	return get_module("syncer").sync_code_links()
end

function M.sync_todo_links()
	return get_module("syncer").sync_todo_links()
end

-- 悬浮预览
function M.preview_todo()
	return get_module("preview").preview_todo()
end

function M.preview_code()
	return get_module("preview").preview_code()
end

-- 清理功能
function M.cleanup_all_links()
	return get_module("cleaner").cleanup_all_links()
end

-- 搜索功能
function M.search_links_by_file(filepath)
	return get_module("searcher").search_links_by_file(filepath)
end

function M.search_links_by_pattern(pattern)
	return get_module("searcher").search_links_by_pattern(pattern)
end

---------------------------------------------------------------------
-- 工具函数（用于模块内部）
---------------------------------------------------------------------

-- 获取工具函数
function M.generate_id()
	return get_module("utils").generate_id()
end

function M.find_task_insert_position(lines)
	return get_module("utils").find_task_insert_position(lines)
end

function M.get_comment_prefix()
	return get_module("utils").get_comment_prefix()
end

function M.is_todo_floating_window(win_id)
	return get_module("utils").is_todo_floating_window(win_id)
end

---------------------------------------------------------------------
-- 配置相关函数
---------------------------------------------------------------------

-- 获取跳转配置
function M.get_jump_config()
	return config.jump
end

-- 获取预览配置
function M.get_preview_config()
	return config.preview
end

-- 获取渲染配置
function M.get_render_config()
	return config.render
end

return M
