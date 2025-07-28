local ParserBrick = {
    name = "parser",
    brick_type = "base",
    description = "通用输出解析器",
}

--- 解析行格式输出 (支持 file:line:col: message 和 file:line: message)
--- @param output string
--- @return table[] 诊断信息表
local function parse_line_output(output)
    local diagnostics = {}

    for line in output:gmatch("[^\r\n]+") do
        -- 优先解析 file:line:col: message
        local file, lnum, col, message = line:match("^(.-):(%d+):(%d+):%s*(.+)$")
        if file and lnum and col and message then
            table.insert(diagnostics, {
                filename = file,
                lnum = tonumber(lnum),
                col = tonumber(col),
                message = message,
                severity = vim.diagnostic.severity.ERROR,
            })
        else
            -- fallback: 支持 file:line: message
            local file2, lnum2, msg2 = line:match("^(.-):(%d+):%s*(.+)$")
            if file2 and lnum2 and msg2 then
                table.insert(diagnostics, {
                    filename = file2,
                    lnum = tonumber(lnum2),
                    col = 0,
                    message = msg2,
                    severity = vim.diagnostic.severity.WARN,
                })
            end
        end
    end

    return diagnostics
end

--- 解析 Linter 输出
--- @param output string Linter 原始输出
--- @param format string 输出格式 (json, line, etc.)
--- @return table[] 统一格式诊断信息
function ParserBrick.resolve(output, format)
    if format == "json" then
        local ok, decoded = pcall(vim.fn.json_decode, output)
        if ok and type(decoded) == "table" then
            return decoded
        else
            return {}
        end
    elseif format == "line" then
        return parse_line_output(output)
    else
        -- 不支持的格式，返回空表避免上层错误
        return {}
    end
end

return ParserBrick

