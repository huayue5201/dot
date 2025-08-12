-- lua/brickdag/bricks/base/cppcheck.lua
local M = {
    name = "cppcheck-pr",
    brick_type = "base",
    description = "解析 cppcheck 输出，生成 diagnostics 列表",
}

--- severity 映射表
local severity_map = {
    error = vim.diagnostic.severity.ERROR,
    warning = vim.diagnostic.severity.WARN,
    style = vim.diagnostic.severity.INFO,
    performance = vim.diagnostic.severity.INFO,
    portability = vim.diagnostic.severity.INFO,
    information = vim.diagnostic.severity.HINT,
    info = vim.diagnostic.severity.HINT,
}

--- 按 format 模板解析
local function parse_with_format(output, format)
    local diagnostics = {}
    -- 生成匹配模式：把 {file} 等替换成捕获组
    local pattern = format
        :gsub("([%%%^%$%(%)%.%[%]%+%-%?%*])", "%%%1") -- 转义 Lua 模式特殊字符
        :gsub("{file}", "(.+)")
        :gsub("{line}", "(%%d+)")
        :gsub("{column}", "(%%d+)")
        :gsub("{severity}", "([^:]+)")
        :gsub("{message}", "(.+)")
    for line in output:gmatch("[^\r\n]+") do
        local file, lnum, col, severity, msg = line:match("^" .. pattern .. "$")
        if file and lnum and severity and msg then
            table.insert(diagnostics, {
                filename = file,
                lnum = tonumber(lnum) - 1,
                col = tonumber(col or 1) - 1,
                message = msg,
                severity = severity_map[severity:lower()] or vim.diagnostic.severity.WARN,
                source = "cppcheck",
            })
        end
    end
    return diagnostics
end

--- 默认正则解析
local function parse_default(output)
    local diagnostics = {}
    for line in output:gmatch("[^\r\n]+") do
        local filename, lnum, severity, msg = line:match("^([^:]+):(%d+): %((%a+)%) (.+)$")
        if filename and lnum and severity and msg then
            table.insert(diagnostics, {
                filename = filename,
                lnum = tonumber(lnum) - 1,
                col = 0,
                message = msg,
                severity = severity_map[severity:lower()] or vim.diagnostic.severity.WARN,
                source = "cppcheck",
            })
        end
    end
    return diagnostics
end

--- 标准基础积木接口
function M.resolve(ctx, task)
    local output = ctx.output or ""
    local opts = task.opts or {}
    if opts.format then
        return parse_with_format(output, opts.format), nil
    else
        return parse_default(output), nil
    end
end

return M

