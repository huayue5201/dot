local M = {
    windows = {
        left = nil,
        center = nil,
        right = nil,
    },
    views = {
        list = require("brickdag.ui.views.list_view"),
        detail = require("brickdag.ui.views.detail_view"),
    },
}

-- 计算窗口布局 (1:1:1) - 固定宽度
local function calculate_layout()
    local total_width = vim.o.columns
    local total_height = vim.o.lines

    -- 固定宽度设置（总宽度的25%）
    local fixed_width = math.floor(total_width * 0.25)
    local gap = 2 -- 窗口间隙

    -- 计算水平居中位置
    local total_used_width = fixed_width * 3 + gap * 2
    local start_col = math.floor((total_width - total_used_width) / 2)

    local height = math.floor(total_height * 0.6)
    local row = math.floor((total_height - height) / 2) -- 垂直居中

    return {
        left = { row = row, col = start_col, width = fixed_width, height = height },
        center = { row = row, col = start_col + fixed_width + gap, width = fixed_width, height = height },
        right = { row = row, col = start_col + (fixed_width + gap) * 2, width = fixed_width, height = height },
    }
end

-- 创建窗口
local function create_window(position, opts)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        title = position,
        title_pos = "center",
        row = opts.row,
        col = opts.col,
        width = opts.width,
        height = opts.height,
        zindex = 50,
    })

    vim.api.nvim_win_set_option(win, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")

    return { win = win, buf = buf }
end

-- 打开所有窗口
function M.open()
    M.close_all()
    local layout = calculate_layout()

    for position, opts in pairs(layout) do
        M.windows[position] = create_window(position, opts)
    end

    M.focus_center()
end

-- 关闭所有窗口
function M.close_all()
    for pos, win_info in pairs(M.windows) do
        if win_info and vim.api.nvim_win_is_valid(win_info.win) then
            vim.api.nvim_win_close(win_info.win, true)
        end
        M.windows[pos] = nil
    end
end

-- 聚焦中间窗口
function M.focus_center()
    if M.windows.center and vim.api.nvim_win_is_valid(M.windows.center.win) then
        vim.api.nvim_set_current_win(M.windows.center.win)
    end
end

-- 安全更新缓冲区
local function safe_buf_update(buf, update_fn)
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then
            return
        end

        local ok, err = pcall(function()
            vim.api.nvim_buf_set_option(buf, "modifiable", true)
            update_fn()
            vim.api.nvim_buf_set_option(buf, "modifiable", false)
        end)

        if not ok then
            vim.notify("缓冲区更新失败: " .. tostring(err), vim.log.levels.ERROR)
        end
    end)
end

-- 更新窗口内容
function M.update_all()
    local state = require("brickdag.ui.state_machine")
    local nav_stack = state.get_nav_stack()

    -- 更新左侧窗口 (历史层级)
    if #nav_stack > 1 then
        local prev_layer = nav_stack[#nav_stack - 1]
        M.update_view("left", "list", {
            title = prev_layer.title or "上一级",
            items = prev_layer.items,
            selected_index = prev_layer.selected_index,
            layer_type = prev_layer.type,
        })
    else
        M.clear_view("left")
    end

    -- 更新中间窗口 (当前层级)
    local current_layer = state.current_layer()
    if current_layer then
        M.update_view("center", "list", {
            title = current_layer.title or "当前",
            items = current_layer.items,
            selected_index = current_layer.selected_index,
            layer_type = current_layer.type,
        })
    else
        M.clear_view("center")
    end

    -- 更新右侧窗口 (下一层级预览)
    local selected_item = state.get_selected_item()
    if selected_item then
        local children = {}
        local layer_type = ""

        if current_layer.type == state.LAYER_TYPES.ROOT then
            children = state.get_task_children(selected_item)
            layer_type = state.LAYER_TYPES.TASK
        elseif current_layer.type == state.LAYER_TYPES.TASK then
            if selected_item.type == "dependency" then
                children = state.get_task_children(selected_item.task)
                layer_type = state.LAYER_TYPES.TASK
            else
                children = state.get_frame_children(selected_item)
                layer_type = state.LAYER_TYPES.FRAME
            end
        elseif current_layer.type == state.LAYER_TYPES.FRAME then
            children = state.get_brick_children(selected_item)
            layer_type = state.LAYER_TYPES.BRICK
        elseif current_layer.type == state.LAYER_TYPES.BRICK then
            children = state.get_value_children(selected_item)
            layer_type = state.LAYER_TYPES.VALUE
        end

        if #children > 0 then
            M.update_view("right", "list", {
                title = "下一级预览",
                items = children,
                selected_index = 1,
                layer_type = layer_type,
            })
        else
            M.update_view("right", "detail", { item = selected_item })
        end
    else
        M.clear_view("right")
    end
end

-- 更新特定视图
function M.update_view(position, view_type, data)
    if not M.windows[position] then
        return
    end

    local win_info = M.windows[position]
    if not vim.api.nvim_win_is_valid(win_info.win) then
        return
    end

    local view = M.views[view_type]
    if not view then
        return
    end

    -- 设置窗口标题
    if data.title then
        vim.api.nvim_win_set_config(win_info.win, {
            title = data.title,
            title_pos = "center",
        })
    end

    safe_buf_update(win_info.buf, function()
        view.render(win_info.buf, data)
    end)
end

-- 清空视图
function M.clear_view(position)
    if not M.windows[position] then
        return
    end

    local win_info = M.windows[position]
    if not win_info.buf or not vim.api.nvim_buf_is_valid(win_info.buf) then
        return
    end

    safe_buf_update(win_info.buf, function()
        vim.api.nvim_buf_set_lines(win_info.buf, 0, -1, false, {})
    end)
end

-- 检查是否在导航界面中
function M.is_in_navigation()
    return M.windows.center and vim.api.nvim_win_is_valid(M.windows.center.win)
end

return M

