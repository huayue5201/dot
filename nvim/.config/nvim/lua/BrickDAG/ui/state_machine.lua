local BricksRegistry = require("brickdag.core.bricks_registry")

local M = {
    nav_stack = {},
    root_tasks = {},
}

M.LAYER_TYPES = {
    ROOT = "root",
    TASK = "task",
    FRAME = "frame",
    BRICK = "brick",
    VALUE = "value",
}

function M.init(tasks)
    M.root_tasks = tasks or {}
    M.nav_stack = {
        {
            type = M.LAYER_TYPES.ROOT,
            items = tasks,
            selected_index = 1,
            title = "任务列表",
        },
    }
end

function M.current_layer()
    return M.nav_stack[#M.nav_stack]
end

function M.get_nav_stack()
    return M.nav_stack
end

--- 获取当前选中项
function M.get_selected_item()
    local layer = M.current_layer()
    if not layer then
        return nil
    end
    return layer.items[layer.selected_index]
end

--- 进入选中项
function M.navigate_into()
    local layer = M.current_layer()
    local selected = M.get_selected_item()
    if not selected then
        return
    end

    local new_layer = {
        parent = layer,
        selected_index = 1,
        title = selected.name or "详情",
    }

    -- 根据不同类型创建新层级
    if layer.type == M.LAYER_TYPES.ROOT then
        new_layer.type = M.LAYER_TYPES.TASK
        new_layer.items = M.get_task_children(selected)
    elseif layer.type == M.LAYER_TYPES.TASK then
        if selected.type == "dependency" then
            new_layer.type = M.LAYER_TYPES.TASK
            new_layer.items = M.get_task_children(selected.task)
        else
            new_layer.type = M.LAYER_TYPES.FRAME
            new_layer.items = M.get_frame_children(selected)
        end
    elseif layer.type == M.LAYER_TYPES.FRAME then
        new_layer.type = M.LAYER_TYPES.BRICK
        new_layer.items = M.get_brick_children(selected)
    elseif layer.type == M.LAYER_TYPES.BRICK then
        new_layer.type = M.LAYER_TYPES.VALUE
        new_layer.items = M.get_value_children(selected)
    else
        return -- 值层没有子级
    end

    table.insert(M.nav_stack, new_layer)
end

--- 返回上一层
function M.navigate_back()
    if #M.nav_stack > 1 then
        table.remove(M.nav_stack)
    end
end

--- 更新选择
function M.update_selection(delta)
    local layer = M.current_layer()
    if not layer then
        return
    end

    local new_index = layer.selected_index + delta
    if new_index >= 1 and new_index <= #layer.items then
        layer.selected_index = new_index
    end
end

--- 获取任务的子项
function M.get_task_children(task)
    local children = {}

    -- 添加框架积木
    for key, value in pairs(task) do
        if key ~= "name" and key ~= "type" and key ~= "deps" and key ~= "description" then
            table.insert(children, {
                name = key,
                value = value,
                type = "frame",
                frame_name = task.type,
            })
        end
    end

    -- 添加依赖任务
    if task.deps and #task.deps > 0 then
        for _, dep_name in ipairs(task.deps) do
            for _, t in ipairs(M.root_tasks) do
                if t.name == dep_name then
                    table.insert(children, {
                        name = "依赖: " .. dep_name,
                        value = t,
                        type = "dependency",
                        task = t,
                    })
                    break
                end
            end
        end
    end

    return children
end

--- 获取框架的子项
function M.get_frame_children(frame)
    local children = {}
    local brick = BricksRegistry.get_frame(frame.frame_name)

    if brick then
        -- 添加框架描述
        table.insert(children, {
            name = "描述",
            value = brick.description,
            type = "description",
        })
    end

    -- 添加配置值
    if type(frame.value) == "table" then
        if vim.tbl_islist(frame.value) then
            for i, v in ipairs(frame.value) do
                table.insert(children, {
                    name = tostring(i),
                    value = v,
                    type = "value",
                })
            end
        else
            for k, v in pairs(frame.value) do
                table.insert(children, {
                    name = k,
                    value = v,
                    type = "value",
                })
            end
        end
    else
        table.insert(children, {
            name = "值",
            value = frame.value,
            type = "value",
        })
    end

    return children
end

--- 获取积木的子项
function M.get_brick_children(brick)
    local children = {}
    local base_brick = BricksRegistry.get_base_brick(brick.name)

    if base_brick then
        -- 添加积木描述
        table.insert(children, {
            name = "描述",
            value = base_brick.description,
            type = "description",
        })
    end

    -- 添加值
    if type(brick.value) == "table" then
        if vim.tbl_islist(brick.value) then
            for i, v in ipairs(brick.value) do
                table.insert(children, {
                    name = tostring(i),
                    value = v,
                    type = "value",
                })
            end
        else
            for k, v in pairs(brick.value) do
                table.insert(children, {
                    name = k,
                    value = v,
                    type = "value",
                })
            end
        end
    else
        table.insert(children, {
            name = "值",
            value = brick.value,
            type = "value",
        })
    end

    return children
end

--- 获取值的子项
function M.get_value_children(value_item)
    -- 值没有子级
    return {}
end

return M

