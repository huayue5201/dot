local M = {}

--- 格式化 value 为展示行
local function format_value(value, indent)
    local lines = {}
    indent = indent or ""

    if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
        table.insert(lines, indent .. tostring(value))
    elseif type(value) == "table" then
        if vim.tbl_islist(value) then
            -- 数组
            for _, v in ipairs(value) do
                if type(v) == "table" then
                    table.insert(lines, indent .. "- " .. vim.inspect(v))
                else
                    table.insert(lines, indent .. "- " .. tostring(v))
                end
            end
        else
            -- 字典
            for k, v in pairs(value) do
                if type(v) == "table" then
                    table.insert(lines, indent .. k .. ":")
                    vim.list_extend(lines, format_value(v, indent .. "  "))
                else
                    table.insert(lines, indent .. k .. ": " .. tostring(v))
                end
            end
        end
    else
        table.insert(lines, indent .. vim.inspect(value))
    end

    return lines
end

function M.render(buf, data)
    if not data then
        return
    end

    local lines = {}
    local item = data.item

    -- 显示任务详情
    if data.layer_type == "task_list" and data.task then
        table.insert(lines, "# 任务详情")
        table.insert(lines, "名称: " .. data.task.name)
        table.insert(lines, "类型: " .. data.task.type)

        if data.task.description then
            table.insert(lines, "")
            table.insert(lines, "描述: " .. data.task.description)
        end

        if data.task.deps and #data.task.deps > 0 then
            table.insert(lines, "")
            table.insert(lines, "依赖: " .. table.concat(data.task.deps, ", "))
        end

    -- 显示框架积木详情
    elseif data.brick_type == "frame" then
        table.insert(lines, "# 框架积木")
        table.insert(lines, "名称: " .. data.brick)
        table.insert(lines, "类型: " .. data.brick_type)

        if data.description then
            table.insert(lines, "")
            table.insert(lines, "描述: " .. data.description)
        end

        if item and item.value then
            table.insert(lines, "")
            table.insert(lines, "配置值:")
            vim.list_extend(lines, format_value(item.value, "  "))
        end

    -- 显示基础积木详情
    elseif data.brick_type == "base" then
        table.insert(lines, "# 基础积木")
        table.insert(lines, "名称: " .. data.brick)
        table.insert(lines, "类型: " .. data.brick_type)

        if data.description then
            table.insert(lines, "")
            table.insert(lines, "描述: " .. data.description)
        end

        if item and item.value then
            table.insert(lines, "")
            table.insert(lines, "值:")
            vim.list_extend(lines, format_value(item.value, "  "))
        end

    -- 显示通用值
    else
        if item and item.value then
            vim.list_extend(lines, format_value(item.value))
        end
    end

    if #lines == 0 then
        table.insert(lines, "> 无详情可展示")
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M

