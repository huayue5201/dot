-- lua/brickdag/core/autocmd.lua
-- 核心模块：为 BrickDAG 任务提供灵活的自动命令绑定能力

local uv = vim.loop
local task_loader = require("brickdag.core.task_loader")

local M = {}

--------------------------------------------------------------------------------
-- 工具：防抖（debounce）
--------------------------------------------------------------------------------
--- 创建一个防抖函数，延迟 ms 毫秒执行
--- @param fn function 要执行的函数
--- @param ms number 延迟时间（毫秒）
--- @return function 包装后的函数
local function debounce(fn, ms)
    local timer
    return function(...)
        local args = { ... }
        if timer then
            timer:stop()
            timer:close()
        end
        timer = uv.new_timer()
        timer:start(ms, 0, function()
            vim.schedule(function()
                fn(unpack(args))
            end)
        end)
    end
end

--------------------------------------------------------------------------------
-- 创建任务执行器
--------------------------------------------------------------------------------
--- 创建一个回调函数，用于执行指定的 BrickDAG 任务（带任务过滤）
--- @param task_name string 任务名称
--- @return function
function M.create_task_runner(task_name)
    return function(args)
        local buf = args.buf

        -- 从任务系统加载当前可执行的任务（会根据 filetype、root_patterns 过滤）
        local tasks = task_loader.load_tasks()
        local found = false
        for _, t in ipairs(tasks) do
            if t.name == task_name then
                found = true
                break
            end
        end

        if not found then
            return -- 当前 buffer 不满足运行条件
        end

        local ok, err = pcall(require("brickdag").run_task_by_name, task_name, buf)
        if not ok then
            vim.notify(
                string.format("[BrickDAG] 任务执行失败: %s\n错误信息: %s", task_name, err),
                vim.log.levels.ERROR
            )
        end
    end
end

--------------------------------------------------------------------------------
-- 动态注册自动命令
--------------------------------------------------------------------------------
--- 为一个任务注册多个事件触发
--- @param task_name string 任务名
--- @param events string[] Neovim 事件列表，例如 { "BufWritePost", "InsertLeave" }
--- @param opts? table 选项 { debounce = 300, group = "MyGroup" }
function M.register_autocmds(task_name, events, opts)
    opts = opts or {}
    local group = opts.group or ("BrickDAG_" .. task_name)
    local delay = opts.debounce or 0

    -- 创建防抖任务执行器
    local runner = M.create_task_runner(task_name)
    if delay > 0 then
        runner = debounce(runner, delay)
    end

    -- 创建 augroup（会先清空）
    local gid = vim.api.nvim_create_augroup(group, { clear = true })

    -- 为每个事件注册
    for _, ev in ipairs(events) do
        vim.api.nvim_create_autocmd(ev, {
            group = gid,
            callback = runner,
        })
    end
end

--------------------------------------------------------------------------------
-- 移除任务的所有自动命令
--------------------------------------------------------------------------------
--- @param task_name string
function M.unregister_autocmds(task_name)
    local group = "BrickDAG_" .. task_name
    pcall(vim.api.nvim_del_augroup_by_name, group)
end

return M

