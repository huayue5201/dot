local uv = vim.loop

local FormatFramework = {
    name = "format",
    brick_type = "frame",
    description = "通用代码格式化框架（支持临时文件方案 & stdin/stdout）",
    version = "2.0.0",
}

-- 默认配置（写在这里，后面会合并）
local default_format_config = {
    method = "file", -- 默认临时文件方案
    notify = true, -- 默认显示通知
}
 local stdin_args = {
  ["-"] = true,
  ["--stdin"] = true,
  -- 可拓展更多支持的参数
}

local function infer_method_from_args(args)
  for _, v in ipairs(args or {}) do
    if stdin_args[v] then
      return "stdin"
    end
  end
  return "file"
end

-- 写临时文件
local function write_buffer_to_tempfile(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local tmpname = vim.fn.tempname()
    local fd = uv.fs_open(tmpname, "w", 438) -- 0o666
    if not fd then
        return nil, "创建临时文件失败"
    end
    local ok, err = pcall(function()
        uv.fs_write(fd, table.concat(lines, "\n"))
    end)
    uv.fs_close(fd)
    if not ok then
        return nil, "写入临时文件失败: " .. err
    end
    return tmpname
end

-- 读临时文件
local function read_tempfile(path)
    local fd = uv.fs_open(path, "r", 438)
    if not fd then
        return nil, "打开临时文件失败"
    end
    local stat = uv.fs_fstat(fd)
    local data = uv.fs_read(fd, stat.size, 0)
    uv.fs_close(fd)
    uv.fs_unlink(path)
    return data
end

function FormatFramework.execute(exec_context)
    local logger = exec_context.services.logger
    local config = exec_context.config

    -- 解析并合并默认配置
    local resolved = FormatFramework.resolve_config(config, exec_context)
    resolved.method = resolved.method or infer_method_from_args(resolved.args)
    resolved.notify = resolved.notify
    if resolved.notify == nil then
        resolved.notify = default_format_config.notify
    end
    if not resolved.method then
        resolved.method = default_format_config.method
    end

    local formatter = resolved.cmd
    if not formatter then
        return false, "未提供格式化命令"
    end

    local args = resolved.args or {}
    local bufnr = vim.api.nvim_get_current_buf()

    if resolved.method == "stdin" then
        local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        local full_cmd = formatter .. " " .. table.concat(args, " ")
        logger(string.format("[FORMAT] 执行(stdin): %s", full_cmd), vim.log.levels.INFO)

        local output = vim.fn.system(full_cmd, text)
        local exit_code = vim.v.shell_error
        if exit_code ~= 0 then
            local msg = string.format("格式化失败 (退出码 %d): %s", exit_code, output)
            logger(msg, vim.log.levels.ERROR)
            if resolved.notify then
                vim.notify(msg, vim.log.levels.ERROR)
            end
            return false, msg
        end
        local lines = vim.split(output, "\n", { plain = true })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        if resolved.notify then
            vim.notify("✅ 格式化完成", vim.log.levels.INFO)
        end
        return true
    else
        local temp_file, err = write_buffer_to_tempfile(bufnr)
        if not temp_file then
            local msg = "临时文件创建失败: " .. err
            if resolved.notify then
                vim.notify(msg, vim.log.levels.ERROR)
            end
            return false, msg
        end

        local args_with_file = vim.deepcopy(args)
        table.insert(args_with_file, temp_file)
        local full_cmd = formatter .. " " .. table.concat(args_with_file, " ")
        logger(string.format("[FORMAT] 执行(file): %s", full_cmd), vim.log.levels.INFO)

        local output = vim.fn.system(full_cmd)
        local exit_code = vim.v.shell_error
        if exit_code ~= 0 then
            local msg = string.format("格式化失败 (退出码 %d): %s", exit_code, output)
            logger(msg, vim.log.levels.ERROR)
            uv.fs_unlink(temp_file)
            if resolved.notify then
                vim.notify(msg, vim.log.levels.ERROR)
            end
            return false, msg
        end

        local formatted, err2 = read_tempfile(temp_file)
        if not formatted then
            local msg = "读取格式化后内容失败: " .. err2
            if resolved.notify then
                vim.notify(msg, vim.log.levels.ERROR)
            end
            return false, msg
        end

        local lines = vim.split(formatted, "\n", { plain = true })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

        if resolved.notify then
            vim.notify("✅ 格式化完成", vim.log.levels.INFO)
        end
        return true
    end
end

function FormatFramework.resolve_config(config, context)
    local services = context.services
    local resolver = services.resolver

    return resolver.resolve_parameters(config, {
        file_path = vim.fn.expand("%:p"),
        file_dir = vim.fn.expand("%:p:h"),
        file_name = vim.fn.expand("%:t"),
        file_type = vim.bo.filetype,
        project_root = context.project_root or vim.fn.getcwd(),
    })
end

return FormatFramework

