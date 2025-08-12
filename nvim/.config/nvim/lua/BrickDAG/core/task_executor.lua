-- lua/brickdag/core/task_executor.lua
local StateMachine = require("brickdag.core.state_machine")
local BricksRegistry = require("brickdag.core.bricks_registry")

local Executor = {}
Executor.__index = Executor

-- 简单事件总线
local function create_event_bus()
    local listeners = {}
    return {
        on = function(event, cb)
            (listeners[event] or (listeners[event] == {}))[#listeners[event] + 1] = cb
        end,
        emit = function(event, ...)
            for _, cb in ipairs(listeners[event] or {}) do
                cb(...)
            end
        end,
    }
end

--- 创建执行器
function Executor.new(user_services)
    local self = setmetatable({}, Executor)
    self.state_machine = StateMachine.new()

    -- 公共服务（registry 自动注入）
    self.services = vim.tbl_deep_extend("force", {
        resolver = require("brickdag.core.value_resolver"),
        logger = function(msg, level)
            vim.notify("[Executor] " .. msg, level or vim.log.levels.INFO)
        end,
        event_bus = create_event_bus(),
        config = {},
        cache = {},
        registry = BricksRegistry,
    }, user_services or {})

    return self
end

--- 执行任务
function Executor:execute_task(context, task_id, task, on_done)
    self.services.logger(("开始执行任务: %s (%s)"):format(task_id, task.type), vim.log.levels.DEBUG)

    -- 检查依赖
    local missing = {}
    for _, dep in ipairs(task.deps or {}) do
        if not context.completed_tasks[dep] then
            missing[#missing + 1] = dep
        end
    end
    if #missing > 0 then
        local err = "未完成依赖: " .. table.concat(missing, ", ")
        context:mark_failed(task_id, err)
        self.services.logger(err, vim.log.levels.WARN)
        return on_done(false, err)
    end

    -- 状态切换
    local ok, err = self.state_machine:transition(StateMachine.STATE_RUNNING)
    if not ok then
        return on_done(false, "状态转换失败: " .. err)
    end

    -- 获取框架
    local framework = self.services.registry.get_frame(task.type)
    if not framework then
        return on_done(false, "框架未注册: " .. task.type)
    end

    local frame_config = task[task.type]
    if not frame_config then
        return on_done(false, "缺少框架配置")
    end

    -- 构建执行上下文
    local exec_context = {
        global_context = context,
        config = frame_config,
        task_id = task_id,
        task = task,
        services = self.services,
        on_done = function(success, err)
            if success then
                context:mark_completed(task_id)
                self.state_machine:transition(StateMachine.STATE_SUCCESS)
                on_done(true)
            else
                context:mark_failed(task_id, err or "未知错误")
                self.state_machine:transition(StateMachine.STATE_FAILED)
                on_done(false, err)
            end
        end,
    }

    -- 执行框架
    local ok_exec, exec_err = pcall(function()
        framework.execute(exec_context)
    end)
    if not ok_exec then
        on_done(false, "框架执行错误: " .. tostring(exec_err))
    end
end

return Executor

