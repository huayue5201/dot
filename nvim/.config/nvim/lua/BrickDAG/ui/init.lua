local state = require("BrickDAG.ui.state_machine")
local winman = require("BrickDAG.ui.window_manager")
local task_loader = require("BrickDAG.core.task_loader")

local M = {}

function M.show_all_tasks()
	local root_tasks = task_loader.load_tasks()
	state.init(root_tasks)
	winman.open()
	winman.update_all()
	M.attach_keymaps()
end

function M.attach_keymaps()
	vim.api.nvim_create_autocmd("WinEnter", {
		callback = function()
			if winman.is_in_navigation() then
				-- 导航快捷键
				local maps = {
					{ "l", M.navigate_into, "进入积木列表" },
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
					{ "q", M.close_navigation, "关闭导航" },
					{ "<CR>", M.run_selected_task, "运行选中任务" },
				}

				for _, map in ipairs(maps) do
					vim.keymap.set("n", map[1], map[2], { buffer = true, desc = map[3] })
				end
			end
		end,
	})
end

function M.run_selected_task()
	local state_machine = require("BrickDAG.ui.state_machine")
	local current_layer = state_machine.current_layer()
	if not current_layer then
		return
	end

	local selected = current_layer.current[current_layer.selected_index]
	if not selected then
		return
	end

	-- 只运行任务，不运行积木参数
	if selected.type and not selected.brick_type then
		require("BrickDAG").run_task(selected)
		vim.notify("任务开始执行: " .. selected.name, vim.log.levels.INFO)
	end
end

function M.close_navigation()
	winman.close_all()
end

function M.is_in_navigation()
	return winman.is_in_navigation()
end

function M.navigate_into()
	state.navigate_into()
	winman.update_all()
end

function M.navigate_back()
	state.navigate_back()
	winman.update_all()
end

function M.navigate_selection(delta)
	state.update_selection(delta)
	winman.update_all()
end

return M
