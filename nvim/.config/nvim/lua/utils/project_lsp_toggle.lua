local json_store = require("utils.json_store")

local M = {}

-- 创建 JSON 存储实例
local state_store = json_store:new({
    file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
    default_data = {},
})

-- 获取当前项目标识（使用路径的哈希值）
local function get_current_project_name()
    local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    local cwd = vim.fn.getcwd()
    local hash = vim.fn.sha256(cwd):sub(1, 8) -- 直接取子串
    return project_name .. "-" .. hash
end

-- 获取当前项目显示名称（用于通知）
local function get_project_display_name()
    return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 读取项目状态缓存
local function load_project_states()
    return state_store:load()
end

-- 保存项目状态到缓存文件
local function save_project_states(states)
    return state_store:save(states)
end

-- 获取当前项目的 LSP 状态
function M.get_lsp_state()
    local project_id = get_current_project_name()
    local states = load_project_states()

    return states[project_id] == nil or states[project_id].enabled
end

function M.set_lsp_state(enabled)
    local project_id = get_current_project_name()
    local project_name = get_project_display_name()
    local states = load_project_states()
    local lsp_name = require("config.lsp").get_lsp_name()

    if not lsp_name then
        vim.notify("No LSP client found for this buffer", vim.log.levels.WARN)
        return
    end

    -- 统一处理 LSP 名称格式（确保是字符串）
    lsp_name = type(lsp_name) == "table" and table.concat(lsp_name, ", ") or lsp_name

    -- 检查状态是否需要更新
    if states[project_id] and states[project_id].enabled == enabled then
        return
    end

    -- 更新状态
    states[project_id] = states[project_id] or {}
    states[project_id].enabled = enabled
    states[project_id].lsp_name = lsp_name

    save_project_states(states)
    vim.g.lsp_enabled = enabled

    vim.notify(
        "LSP " .. (enabled and "enabled" or "disabled") .. " for project: " .. project_name .. " using " .. lsp_name
    )
end

-- 初始化 LSP 状态
function M.init()
    vim.g.lsp_enabled = M.get_lsp_state()
end

return M

