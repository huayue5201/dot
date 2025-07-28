-- lua/brickdag/utils/task_filter.lua

local M = {}

--- 从任务配置中提取过滤条件
--- @param task table 任务配置
--- @return table? filetypes, table? root_patterns
local function extract_filter_conditions(task)
    -- 1. 优先从任务类型专属配置块获取
    if task.type and task[task.type] then
        local config = task[task.type]
        return config.filetypes, config.root_patterns
    end

    -- 2. 特殊处理 lint 类型（向后兼容）
    if task.lint then
        return task.lint.filetypes, task.lint.root_patterns
    end

    return nil, nil
end

--- 评估过滤条件
--- @param condition any 过滤条件配置
--- @param context_value any 当前上下文值
--- @return boolean 是否满足条件
local function evaluate_condition(condition, context_value)
    if condition == nil then
        return true -- 未配置条件视为匹配
    end

    -- 函数类型条件
    if type(condition) == "function" then
        return condition(context_value) == true
    end

    -- 列表类型条件
    if type(condition) == "table" then
        for _, value in ipairs(condition) do
            if value == context_value then
                return true
            end
        end
        return false
    end

    -- 简单值条件
    return condition == context_value
end

--- 任务过滤主函数
--- @param tasks table[] 任务列表
--- @return table[] 过滤后的任务列表
function M.filter(tasks)
    if not tasks or type(tasks) ~= "table" then
        return {}
    end

    local result = {}
    local current_filetype = vim.bo.filetype or ""
    local current_cwd = vim.fn.getcwd()

    for _, task in ipairs(tasks) do
        -- 基本验证：任务必须包含名称和类型
        if type(task) == "table" and task.name and task.type then
            local filetypes, root_patterns = extract_filter_conditions(task)

            local filetype_ok = evaluate_condition(filetypes, current_filetype)
            local root_ok = evaluate_condition(root_patterns, current_cwd)

            if filetype_ok and root_ok then
                table.insert(result, task)
            end
        end
    end

    return result
end

return M

