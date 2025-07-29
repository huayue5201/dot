local M = {}

local function format_value(value, indent)
    indent = indent or ""
    local lines = {}

    if type(value) == "table" then
        if vim.tbl_islist(value) then
            for i, v in ipairs(value) do
                table.insert(lines, indent .. tostring(i) .. ": " .. format_value(v, indent .. "  "))
            end
        else
            for k, v in pairs(value) do
                table.insert(lines, indent .. tostring(k) .. ": " .. format_value(v, indent .. "  "))
            end
        end
    else
        return tostring(value)
    end

    return table.concat(lines, "\n")
end

function M.render(buf, data)
    if not data or not data.item then
        return
    end

    local item = data.item
    local lines = {}

    -- 显示项目信息
    if item.name then
        table.insert(lines, "名称: " .. item.name)
    end

    if item.type then
        table.insert(lines, "类型: " .. item.type)
    end

    if item.frame_name then
        table.insert(lines, "框架: " .. item.frame_name)
    end

    -- 显示值
    if item.value ~= nil then
        table.insert(lines, "值:")
        local value_str = format_value(item.value, "  ")

        -- 处理多行值
        for line in value_str:gmatch("[^\n]+") do
            table.insert(lines, "  " .. line)
        end
    end

    if #lines == 0 then
        table.insert(lines, "无详情可展示")
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M

