-- lua/todo/link/init.lua
local M = {}

---------------------------------------------------------------------
-- 默认配置
---------------------------------------------------------------------
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

---------------------------------------------------------------------
-- 当前配置
---------------------------------------------------------------------
local config = vim.deepcopy(default_config)

---------------------------------------------------------------------
-- 延迟加载子模块（局部变量）
---------------------------------------------------------------------
local utils
local creator
local jumper
local renderer
local syncer
local preview
local cleaner
local searcher

---------------------------------------------------------------------
-- 动态获取模块（lazy require）
---------------------------------------------------------------------
local function get_module(name)
	if name == "utils" then
		if not utils then
			utils = require("todo2.link.utils")
		end
		return utils
	elseif name == "creator" then
		if not creator then
			creator = require("todo2.link.creator")
		end
		return creator
	elseif name == "jumper" then
		if not jumper then
			jumper = require("todo2.link.jumper")
		end
		return jumper
	elseif name == "renderer" then
		if not renderer then
			renderer = require("todo2.link.renderer")
		end
		return renderer
	elseif name == "syncer" then
		if not syncer then
			syncer = require("todo2.link.syncer")
		end
		return syncer
	elseif name == "preview" then
		if not preview then
			preview = require("todo2.link.preview")
		end
		return preview
	elseif name == "cleaner" then
		if not cleaner then
			cleaner = require("todo2.link.cleaner")
		end
		return cleaner
	elseif name == "searcher" then
		if not searcher then
			searcher = require("todo2.link.searcher")
		end
		return searcher
	end
end

---------------------------------------------------------------------
-- 配置管理函数
---------------------------------------------------------------------
function M.setup(user_config)
	config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), user_config or {})
end

function M.get_jump_config()
	return config.jump or default_config.jump
end

function M.get_preview_config()
	return config.preview or default_config.preview
end

function M.get_render_config()
	return config.render or default_config.render
end

function M.get_config()
	return config
end

---------------------------------------------------------------------
-- 公开 API（保持与原 link.lua 相同）
---------------------------------------------------------------------

-- 创建链接（代码 → TODO）
function M.create_link()
	return get_module("creator").create_link()
end

-- 跳转（代码 → TODO）
function M.jump_to_todo()
	return get_module("jumper").jump_to_todo()
end

-- 跳转（TODO → 代码）
function M.jump_to_code()
	return get_module("jumper").jump_to_code()
end

-- 动态跳转（自动判断方向）
function M.jump_dynamic()
	return get_module("jumper").jump_dynamic()
end

-- 渲染代码中的 TODO 状态
function M.render_code_status(bufnr)
	return get_module("renderer").render_code_status(bufnr)
end

-- 同步代码文件中的 TODO 链接
function M.sync_code_links()
	return get_module("syncer").sync_code_links()
end

-- 同步 TODO 文件中的链接
function M.sync_todo_links()
	return get_module("syncer").sync_todo_links()
end

-- 悬浮预览 TODO
function M.preview_todo()
	return get_module("preview").preview_todo()
end

-- 悬浮预览代码
function M.preview_code()
	return get_module("preview").preview_code()
end

-- 清理所有无效链接
function M.cleanup_all_links()
	return get_module("cleaner").cleanup_all_links()
end

-- 搜索链接（按文件）
function M.search_links_by_file(filepath)
	return get_module("searcher").search_links_by_file(filepath)
end

-- 搜索链接（按模式）
function M.search_links_by_pattern(pattern)
	return get_module("searcher").search_links_by_pattern(pattern)
end

---------------------------------------------------------------------
-- 工具函数（供内部模块调用）
---------------------------------------------------------------------
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

return M
