local icon_manager = require("brickdag.core.icon_manager")

local M = {}

local function get_item_icon(item)
    if not item then
        return "○"
    end

    if item.type == "dependency" then
        return "←"
    elseif item.type == "frame" then
        return "⚙️"
    elseif item.type == "description" then
        return "📝"
    end

    return icon_manager.get_icon(item) or "○"
end

local function get_item_text(item)
    if item.name then
        return item.name
    elseif type(item.value) == "string" then
        return item.value
    elseif type(item.value) == "table" then
        return "(表格)"
    else
        return tostring(item.value)
    end
end

function M.render(buf, data)
    local items = data.items or {}
    local selected_index = data.selected_index or 1
    local lines = {}

    -- 添加项目
    for i, item in ipairs(items) do
        local prefix = (i == selected_index) and "▶ " or "  "
        local icon = get_item_icon(item)
        local text = get_item_text(item)

        -- 截断过长的文本
        if #text > 25 then
            text = text:sub(1, 22) .. "..."
        end

        table.insert(lines, prefix .. icon .. " " .. text)
    end

    if #items == 0 then
        table.insert(lines, "> 无内容")
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- 高亮选中项
    if #items > 0 and selected_index >= 1 and selected_index <= #items then
        vim.api.nvim_buf_add_highlight(buf, -1, "Visual", selected_index - 1, 0, -1)
    end

    vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M

