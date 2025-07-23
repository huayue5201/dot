-- lua/brickdag/core/autocmd.lua
-- 核心模块：提供生成执行 BrickDAG 任务的回调函数接口，方便用户自行绑定 Neovim 事件

local M = {}

--- 创建一个回调函数，用于执行指定的 BrickDAG 任务
--- @param task_name string 任务名称
--- @return function 适合用作 Neovim autocmd callback 的函数，参数为 event table
function M.create_task_runner(task_name)
    return function(args)
        local buf = args.buf
        -- 这里可根据需要扩展，比如检测文件类型、判断是否加载任务等
        local ok, err = pcall(require("brickdag").run_task_by_name, task_name, buf)
        if not ok then
            vim.notify(
                string.format("[BrickDAG] 任务执行失败: %s\n错误信息: %s", task_name, err),
                vim.log.levels.ERROR
            )
        end
    end
end

return M
