-- lua/lsp/project_state.lua
local json_store = require("utils.json_store")

local M = {}

-- =============================================
-- 状态存储初始化
-- =============================================

-- 创建项目级状态存储
local project_state_store = json_store:new({
    file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
    default_data = {},
    auto_save = true,
})

-- 创建缓冲区级状态存储
local buffer_state_store = json_store:new({
    file_path = vim.fn.stdpath("cache") .. "/buffer_lsp_states.json",
    default_data = {},
    auto_save = true,
})

-- =============================================
-- 项目标识管理
-- =============================================

function M.get_current_project_id()
    local cwd = vim.fn.getcwd()
    local name = vim.fn.fnamemodify(cwd, ":t")
    local hash = vim.fn.sha256(cwd):sub(1, 8)
    return name .. "-" .. hash
end

function M.get_file_key(file_path)
    if not file_path or file_path == "" then
        return nil
    end
    return vim.fn.fnamemodify(file_path, ":p")
end

-- =============================================
-- 项目级 LSP 状态管理
-- =============================================

function M.is_lsp_enabled(lsp_name)
    local project_id = M.get_current_project_id()
    local states = project_state_store:load()
    local project_states = states[project_id]

    if not project_states or not project_states[lsp_name] then
        return true -- 默认启用
    end

    return project_states[lsp_name].enabled
end

function M.set_lsp_state(lsp_name, enabled)
    local project_id = M.get_current_project_id()
    local states = project_state_store:load()

    states[project_id] = states[project_id] or {}
    states[project_id][lsp_name] = {
        enabled = enabled,
        timestamp = os.time(),
    }

    project_state_store:set(project_id, states[project_id])
    vim.notify(string.format("LSP %s: %s", lsp_name, enabled and "已启用" or "已禁用"), vim.log.levels.INFO)
end

function M.get_project_lsp_states()
    local project_id = M.get_current_project_id()
    local states = project_state_store:load()
    return states[project_id] or {}
end

-- =============================================
-- 缓冲区级 LSP 状态管理
-- =============================================

function M.set_buffer_lsp_state(bufnr, lsp_name, enabled)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local file_key = M.get_file_key(file_path)

    if not file_key then
        -- 无名缓冲区，使用基于 bufnr 的临时存储
        file_key = "buffer_" .. tostring(bufnr)
    end

    local states = buffer_state_store:load()
    states[file_key] = states[file_key] or {}
    states[file_key][lsp_name] = enabled

    buffer_state_store:set(file_key, states[file_key])
end

function M.get_buffer_lsp_state(bufnr, lsp_name)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local file_key = M.get_file_key(file_path)

    if not file_key then
        file_key = "buffer_" .. tostring(bufnr)
    end

    local file_states = buffer_state_store:get(file_key) or {}
    return file_states[lsp_name] -- 返回 nil、true 或 false
end

function M.get_all_buffer_states(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local file_key = M.get_file_key(file_path)

    if not file_key then
        file_key = "buffer_" .. tostring(bufnr)
    end

    return buffer_state_store:get(file_key) or {}
end

function M.cleanup_buffer_state(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local file_path = vim.api.nvim_buf_get_name(bufnr)
    local file_key = M.get_file_key(file_path)

    if not file_key then
        file_key = "buffer_" .. tostring(bufnr)
    end

    buffer_state_store:delete(file_key)
end

function M.get_disabled_lsps_for_buffer(bufnr)
    local states = M.get_all_buffer_states(bufnr)
    local disabled = {}

    for lsp_name, enabled in pairs(states) do
        if enabled == false then
            table.insert(disabled, lsp_name)
        end
    end

    return disabled
end

-- =============================================
-- 组合状态检查（项目级 + 缓冲区级）
-- =============================================

function M.is_lsp_enabled_for_buffer(lsp_name, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    -- 1. 先检查缓冲区级状态（最高优先级）
    local buffer_enabled = M.get_buffer_lsp_state(bufnr, lsp_name)
    if buffer_enabled ~= nil then
        return buffer_enabled
    end

    -- 2. 再检查项目级状态
    return M.is_lsp_enabled(lsp_name)
end

-- =============================================
-- 工具函数
-- =============================================

function M.get_project_buffer_states()
    return buffer_state_store:load()
end

function M.cleanup_invalid_buffer_states()
    local all_buffer_states = buffer_state_store:load()
    local valid_states = {}
    local cleaned_count = 0

    for file_key, file_states in pairs(all_buffer_states) do
        if file_key:match("^buffer_%d+$") then
            -- 临时缓冲区状态，检查缓冲区是否仍然有效
            local bufnr = tonumber(file_key:match("buffer_(%d+)"))
            if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
                valid_states[file_key] = file_states
            else
                cleaned_count = cleaned_count + 1
            end
        else
            -- 文件路径状态，检查文件是否存在
            if vim.fn.filereadable(file_key) == 1 then
                valid_states[file_key] = file_states
            else
                cleaned_count = cleaned_count + 1
            end
        end
    end

    if cleaned_count > 0 then
        -- 清空并重新设置有效状态
        buffer_state_store:clear()
        for file_key, file_states in pairs(valid_states) do
            buffer_state_store:set(file_key, file_states)
        end
        vim.notify(string.format("清理了 %d 个无效的缓冲区状态", cleaned_count), vim.log.levels.INFO)
    end

    return cleaned_count
end

function M.show_project_stats()
    local project_id = M.get_current_project_id()
    local project_states = M.get_project_lsp_states()
    local all_buffer_states = M.get_project_buffer_states()

    local project_lsp_count = vim.tbl_count(project_states)
    local buffer_file_count = 0
    local temp_buffer_count = 0

    for file_key, file_states in pairs(all_buffer_states) do
        if file_key:match("^buffer_%d+$") then
            temp_buffer_count = temp_buffer_count + 1
        else
            buffer_file_count = buffer_file_count + 1
        end
    end

    print("=== 项目状态统计 ===")
    print(string.format("项目: %s", project_id))
    print(string.format("项目级 LSP 状态: %d 个", project_lsp_count))
    print(string.format("缓冲区级 LSP 状态: %d 个文件, %d 个临时缓冲区", buffer_file_count, temp_buffer_count))

    -- 显示项目级状态
    if not vim.tbl_isempty(project_states) then
        print("\n项目级 LSP 状态:")
        for lsp_name, state in pairs(project_states) do
            local status = state.enabled and "启用" or "禁用"
            print(string.format("  %s: %s", lsp_name, status))
        end
    end
end

return M
