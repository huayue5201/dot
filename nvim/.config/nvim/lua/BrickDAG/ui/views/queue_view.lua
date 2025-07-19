local state = require("brickdag.ui.state_machine")
local winman = require("brickdag.ui.window_manager")
local task_queue = require("brickdag.core.task_queue")
local runner = require("brickdag.core.task_runner")
local M = {}

-- 初始化任务队列的导航状态，和tn逻辑类似
function M.show()
	local tasks = task_queue.all()
	if #tasks == 0 then
		vim.notify("任务队列为空", vim.log.levels.INFO)
		return
	end
	-- 使用状态机管理当前层，任务队列作为一层
	state.init({ { current = tasks, selected_index = 1 } })
	winman.open_queue_view() -- 你需要确保window_manager支持打开这3个窗体

	winman.update_all()

	-- 复用和tn类似的键映射绑定方式
	M.attach_keymaps()
end

function M.attach_keymaps()
	vim.api.nvim_create_autocmd("WinEnter", {
		callback = function()
			if winman.is_in_queue_view() then
				local maps = {
					{ "l", M.navigate_into, "进入任务详情" },
					{ "h", M.navigate_back, "返回上层" },
					{
						"j",
						function()
							M.navigate_selection(1)
						end,
						"下移选择",
					},
					{
						"k",
						function()
							M.navigate_selection(-1)
						end,
						"上移选择",
					},
					{ "q", M.close, "关闭任务队列视图" },
					{ "<CR>", M.run_selected_task, "运行选中任务" },
					{ "d", M.delete_selected_task, "删除选中任务" },
				}

				for _, map in ipairs(maps) do
					vim.keymap.set("n", map[1], map[2], { buffer = true, desc = map[3] })
				end
			end
		end,
	})
end

-- 进入任务详情（中间窗口视图更新）
function M.navigate_into()
	-- 根据你现有state_machine逻辑实现层级进入，任务队列可能没有下层，具体看你的设计
	-- 这里简单调用状态机的navigate_into，并刷新
	state.navigate_into()
	winman.update_all()
end

-- 返回上层
function M.navigate_back()
	state.navigate_back()
	winman.update_all()
end

-- 上下移动选择
function M.navigate_selection(delta)
	state.update_selection(delta)
	winman.update_all()
end

-- 运行当前选中任务
function M.run_selected_task()
	local current_layer = state.current_layer()
	if not current_layer or not current_layer.current then
		return
	end
	local selected = current_layer.current[current_layer.selected_index]
	if not selected then
		return
	end
	-- 运行任务
	runner.run({ selected }, function(success, err)
		if success then
			vim.notify("✅ 任务完成: " .. selected.name, vim.log.levels.INFO)
		else
			vim.notify("❌ 任务失败: " .. selected.name .. "\n" .. (err or ""), vim.log.levels.ERROR)
		end
	end)
end

-- 删除当前选中任务
function M.delete_selected_task()
	local current_layer = state.current_layer()
	if not current_layer or not current_layer.current then
		return
	end
	local idx = current_layer.selected_index
	if not idx or not current_layer.current[idx] then
		return
	end
	-- 删除队列任务
	task_queue.remove(idx)

	-- 更新状态机层数据，移除选中任务
	table.remove(current_layer.current, idx)
	if idx > #current_layer.current then
		current_layer.selected_index = #current_layer.current
	end
	if current_layer.selected_index < 1 then
		current_layer.selected_index = 1
	end
	winman.update_all()
	vim.notify("已删除选中任务", vim.log.levels.INFO)
end

-- 关闭队列视图
function M.close()
	winman.close_queue_view()
	vim.notify("关闭任务队列视图", vim.log.levels.INFO)
end

return M
