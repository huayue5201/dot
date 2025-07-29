-- lua/brickdag/core/task_runner.lua

local TaskDAG = require("brickdag.core.task_dag")
local Context = require("brickdag.core.context")
local Executor = require("brickdag.core.task_executor")
local ParallelRunner = require("brickdag.core.parallel_runner")
local StateMachine = require("brickdag.core.state_machine")

local M = {}

-- 默认服务对象
local default_services = {
    logger = function(msg, level)
        vim.notify("[brickdag] " .. msg, level or vim.log.levels.INFO)
    end,
    resolver = require("brickdag.core.value_resolver"),
}

-- 运行任务的核心方法 (异步版本)
--- @param tasks table|table[] 任务或任务列表
--- @param on_done fun(success: boolean, err?: string) 执行完成回调
--- @param user_services table? 用户提供的依赖服务
--- @return boolean 启动成功
function M.run(tasks, on_done, user_services)
    -- 参数验证
    if not on_done or type(on_done) ~= "function" then
        vim.notify("必须提供on_done回调函数", vim.log.levels.ERROR)
        return false
    end

    -- 确保tasks是列表
    if not vim.isarray(tasks) then
        tasks = { tasks }
    end

    -- 合并服务对象
    local services = vim.tbl_deep_extend("force", {}, default_services, user_services or {})

    -- 创建DAG
    local dag = TaskDAG.new()
    for _, task in ipairs(tasks) do
        dag:add_task(task)
    end

    -- 创建执行上下文
    local context = Context.new(dag)

    -- 获取执行层级
    local execution_levels
    local ok, err = pcall(function()
        execution_levels = dag:get_execution_levels()
    end)

    if not ok then
        on_done(false, "依赖分析失败: " .. tostring(err))
        return false
    end

    -- 创建执行器（注入服务）
    local executor = Executor.new(services)

    -- 按层级执行任务
    local level_index = 1
    local any_failed = false
    local all_errors = {}

    local function run_next_level()
        if level_index > #execution_levels then
            -- 所有层级完成
            on_done(not any_failed, any_failed and table.concat(all_errors, "\n") or nil)
            return
        end

        local current_level = execution_levels[level_index]
        services.logger("开始执行层级 " .. level_index, vim.log.levels.INFO)

        if #current_level == 0 then
            -- 空层级直接跳过
            level_index = level_index + 1
            vim.schedule(run_next_level)
            return
        end

        if #current_level == 1 then
            -- 单任务直接执行
            local task_info = current_level[1]
            context:get_task_state(task_info.id):transition(StateMachine.STATE_RUNNING)

            executor:execute_task(context, task_info.id, task_info.task, function(success, err)
                if not success then
                    any_failed = true
                    table.insert(all_errors, string.format("%s: %s", task_info.id, err))
                end
                level_index = level_index + 1
                vim.schedule(run_next_level)
            end)
        else
            -- 并行执行层级任务
            ParallelRunner.run_parallel(current_level, executor, context, function(group_success, group_errors)
                if not group_success then
                    any_failed = true
                    vim.list_extend(all_errors, group_errors)
                end
                level_index = level_index + 1
                vim.schedule(run_next_level)
            end)
        end
    end

    -- 开始执行
    vim.schedule(run_next_level)
    return true
end

return M

