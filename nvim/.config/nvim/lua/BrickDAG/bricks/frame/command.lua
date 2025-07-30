-- lua/brickdag/bricks/frame/command.lua
local uv = vim.loop

local CommandFramework = {
    name = "command",
    brick_type = "frame",
    description = "通用命令行执行框架（异步版，环境变量由env积木注入）",
    version = "1.3.0",
}

--- 参数解析器（支持 table / string）
local function parse_args(args)
    if not args then
        return {}
    end
    if type(args) == "table" then
        return vim.deepcopy(args)
    elseif type(args) == "string" then
        local parsed = {}
        for a, b, c in args:gmatch([["([^"]+)"|'([^']+)'|(%S+)"]]) do
            local token = a or b or c
            if token and token ~= "" then
                table.insert(parsed, token)
            end
        end
        return parsed
    end
    return {}
end

--- 执行命令任务
--- @param exec_context table 执行上下文
--- @param callback? fun(ok:boolean, msg:string) 异步回调
function CommandFramework.execute(exec_context, callback)
    local services = exec_context.services
    local config = exec_context.config or {}
    local logger = services and services.logger or vim.notify

    local resolved_cmd = config.cmd
    local resolved_args = parse_args(config.args)
    local resolved_env = exec_context.env or {} -- 已由 env 积木注入
    local resolved_cwd = config.cwd
    local capture_output = config.output
    local timeout = config.timeout or 0
    local async = config.async ~= false -- 默认异步

    -- 校验命令
    if not resolved_cmd then
        local msg = "缺少命令配置 (cmd)"
        if callback then
            callback(false, msg)
        end
        return false, msg
    end
    if vim.fn.executable(resolved_cmd) == 0 then
        local msg = string.format("命令不可执行: %s", resolved_cmd)
        if callback then
            callback(false, msg)
        end
        return false, msg
    end

    local cmd_array = { resolved_cmd }
    vim.list_extend(cmd_array, resolved_args)
    local full_cmd = table.concat(cmd_array, " ")

    logger("[COMMAND] 执行命令: " .. full_cmd, vim.log.levels.INFO)
    if resolved_cwd then
        logger("工作目录: " .. resolved_cwd, vim.log.levels.DEBUG)
    end

    local options = {
        cwd = resolved_cwd,
        env = resolved_env,
        text = true,
    }

    if async then
        local timed_out = false
        local timer
        local handle

        if timeout > 0 then
            timer = uv.new_timer()
            timer:start(timeout * 1000, 0, function()
                timed_out = true
                if handle and handle.kill then
                    handle:kill("sigterm")
                end
                if callback then
                    vim.schedule(function()
                        callback(false, string.format("命令超时（%ds）: %s", timeout, full_cmd))
                    end)
                end
                timer:stop()
                timer:close()
            end)
        end

        handle = vim.system(cmd_array, options, function(obj)
            if timed_out then
                return
            end
            if timer then
                timer:stop()
                timer:close()
            end

            local result = {}
            if obj.stdout then
                for line in obj.stdout:gmatch("[^\r\n]+") do
                    table.insert(result, line)
                end
            end
            if obj.stderr then
                for line in obj.stderr:gmatch("[^\r\n]+") do
                    table.insert(result, line)
                end
            end

            if obj.code == 0 then
                local msg = "命令执行成功"
                if capture_output and #result > 0 then
                    msg = msg .. "\n" .. table.concat(result, "\n")
                end
                if callback then
                    vim.schedule(function()
                        callback(true, msg)
                    end)
                end
            else
                local msg = string.format("命令失败 (退出码 %d)", obj.code)
                if #result > 0 then
                    msg = msg .. ":\n" .. table.concat(result, "\n")
                end
                if callback then
                    vim.schedule(function()
                        callback(false, msg)
                    end)
                end
            end
        end)
        return true
    else
        -- 同步执行
        local handle = vim.system(cmd_array, options)
        local obj = handle:wait()
        if obj.code == 0 then
            local msg = "命令执行成功"
            if capture_output and obj.stdout then
                msg = msg .. "\n" .. obj.stdout
            end
            if callback then
                callback(true, msg)
            end
            return true, msg
        else
            local msg = string.format("命令失败 (退出码 %d)", obj.code)
            if obj.stderr then
                msg = msg .. ":\n" .. obj.stderr
            end
            if callback then
                callback(false, msg)
            end
            return false, msg
        end
    end
end

return CommandFramework

