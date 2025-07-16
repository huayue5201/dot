-- BrickDAG/ui/tri_window_context.lua
-- 负责管理三窗口的内容刷新与清空，统一处理缓冲区写入时的 modifiable 状态，防止错误

local manager = require("BrickDAG.ui.tri_window_manager")

-- 延迟加载视图模块，按类型调用对应视图渲染函数
local view_loaders = {
	task_list = function()
		return require("BrickDAG.ui.views.task_list_view")
	end,
	brick_detail = function()
		return require("BrickDAG.ui.views.brick_detail_view")
	end,
	-- 其他视图类型可继续添加
}

local M = {}

--- 统一封装缓冲区写入操作，确保写入期间 buffer 处于 modifiable 状态
--- @param bufnr number 目标 buffer 编号
--- @param write_fn function 实际写入操作的函数，无参数
local function write_to_buf(bufnr, write_fn)
	-- 先查询当前 modifiable 状态
	local modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")
	-- 如果不可修改，则先设为可修改
	if not modifiable then
		vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
	end

	-- 调用写入函数执行实际写入
	write_fn()

	-- 恢复写入前的 modifiable 状态
	if not modifiable then
		vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
	end
end

--- 更新所有三个窗口，根据传入的 display_def 定义依次更新或清空
--- @param display_def table { left=..., center=..., right=... } 每项为视图定义或 nil
function M.update_all(display_def)
	-- 确保三个窗口处于打开状态
	manager.ensure_open()

	-- 左侧窗口处理
	if display_def.left then
		M.update_window("left", display_def.left)
	else
		M.clear_window("left")
	end

	-- 中间窗口处理
	if display_def.center then
		M.update_window("center", display_def.center)
	else
		M.clear_window("center")
	end

	-- 右侧窗口处理
	if display_def.right then
		M.update_window("right", display_def.right)
	else
		M.clear_window("right")
	end

	-- 聚焦中间窗口
	manager.focus_center()
end

--- 更新指定位置窗口的内容
--- @param position string 窗口位置，"left"/"center"/"right"
--- @param def table 视图定义，含 type/data/selected_index 等字段
function M.update_window(position, def)
	local win_info = manager.windows[position]
	if not win_info or not vim.api.nvim_win_is_valid(win_info.win) then
		return
	end

	local loader = view_loaders[def.type]
	if not loader then
		return
	end

	local view = loader()
	if not view then
		return
	end

	-- 通过统一的写入封装调用视图渲染，视图负责具体写入逻辑
	write_to_buf(win_info.buf, function()
		view.render(win_info.buf, {
			win = win_info.win,
			name = position,
			type = def.type,
			data = def.data,
			selected_index = def.selected_index,
		})
	end)
end

--- 清空指定位置窗口内容
--- @param position string 窗口位置，"left"/"center"/"right"
function M.clear_window(position)
	local win_info = manager.windows[position]
	if not win_info or not vim.api.nvim_win_is_valid(win_info.win) then
		return
	end

	-- 统一写入封装，清空 buffer 内容
	write_to_buf(win_info.buf, function()
		vim.api.nvim_buf_set_lines(win_info.buf, 0, -1, false, {})
	end)
end

return M
