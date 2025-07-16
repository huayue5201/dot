local state = require("BrickDAG.ui.state")
local display_ctrl = require("BrickDAG.ui.task_display_controller")
local task_loader = require("BrickDAG.core.task_loader")
local winman = require("BrickDAG.ui.tri_window_manager")

local M = {}

function M.show_all_tasks()
	-- 确保窗口关闭状态
	winman.close_all()

	-- 加载真实任务数据
	local root_tasks = task_loader.load_tasks()

	-- 初始化状态
	state.init(root_tasks)

	-- 打开三窗口布局
	winman.open()

	-- 渲染导航
	display_ctrl.render_navigation()
end

-- 关闭任务导航界面
function M.close_navigation()
	winman.close_all()
	state.init({}) -- 重置状态
end

-- 检查是否在任务导航界面
function M.is_in_navigation()
	return winman.is_open()
end

return M
