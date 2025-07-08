-- init.lua
local registry = require("BrickDAG.core.bricks_registry")
local loader = require("BrickDAG.core.brick_loader")
-- local task_loader = require("BrickDAG.core.task_loader")
local runner = require("BrickDAG.core.task_runner")
local interaction = require("BrickDAG.ui.interaction")

local M = {
	-- 暴露运行时注册接口
	runtime_register_base_brick = registry.runtime_register_base_brick,
	runtime_register_frame_brick = registry.runtime_register_frame_brick,

	-- 暴露任务运行接口
	run_tasks = runner.run,
}

--- 设置任务系统
--- @param opts table? 配置选项
function M.setup(opts)
	opts = opts or {}

	-- 清除之前的注册
	registry.clear()

	-- 加载所有积木
	loader.load_all()

	-- 加载运行时任务（可能包含自定义积木注册）
	if opts.runtime_tasks then
		for _, task_module in ipairs(opts.runtime_tasks) do
			local ok, task = pcall(require, task_module)
			if ok and task then
				-- 任务会被添加到系统，其中可能包含自定义积木的注册
				-- 实际任务执行会在后续进行
			end
		end
	end

	-- 设置快捷键
	vim.keymap.set("n", "<leader>or", function()
		interaction.pick_and_run()
	end, { desc = "任务表" })

	vim.keymap.set("n", "<leader>oa", function()
		require("BrickDAG.ui.ui_queue").pick_task_and_enqueue()
	end, { desc = "添加任务到队列" })

	vim.keymap.set("n", "<leader>oq", function()
		require("BrickDAG.ui.ui_queue").manage_queue()
	end, { desc = "管理任务队列" })
end

return M
