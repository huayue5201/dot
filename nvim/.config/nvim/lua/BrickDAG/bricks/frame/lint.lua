local uv = vim.loop
local api = vim.api

--- Lint 框架积木定义
local LintFramework = {
    name = "lint", -- 框架名称
    brick_type = "frame", -- 框架积木类型
    description = "通用Lint执行框架（集成诊断显示）",
}

-- 创建独立命名空间，避免和其他插件或内置诊断冲突
local namespace = api.nvim_create_namespace("brickdag_lint")

--------------------------------------------------------------------------------
-- 发布诊断信息到指定缓冲区
--------------------------------------------------------------------------------
--- @param bufnr number 目标缓冲区编号
--- @param diagnostics table[] 诊断信息列表
local function publish_diagnostics(bufnr, diagnostics)
    vim.diagnostic.set(namespace, bufnr, diagnostics, {
        underline = true, -- 下划线标记问题位置
        virtual_text = true, -- 右侧显示诊断信息
        signs = true, -- 左侧显示标记符号
        update_in_insert = false, -- 插入模式不更新诊断
    })
end

--------------------------------------------------------------------------------
-- 异步执行 lint 命令，捕获 stdout 和 stderr
--------------------------------------------------------------------------------
--- @param cmd string lint 命令
--- @param args table 命令参数列表
--- @param on_exit function 回调，参数 (stdout, stderr, exit_code, signal)
local function run_lint_command(cmd, args, on_exit)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)
    local stdout_chunks = {}
    local stderr_chunks = {}

    -- 启动子进程执行命令
    local handle
    handle = uv.spawn(cmd, {
        args = args,
        stdio = { nil, stdout, stderr },
    }, function(code, signal)
        stdout:close()
        stderr:close()
        handle:close()

        -- 命令结束后，调用回调返回数据
        on_exit(table.concat(stdout_chunks, ""), table.concat(stderr_chunks, ""), code, signal)
    end)

    -- 读取标准输出流
    uv.read_start(stdout, function(err, data)
        if err then
            vim.schedule(function()
                vim.notify("Lint stdout 读取错误: " .. err, vim.log.levels.ERROR)
            end)
            return
        end
        if data then
            table.insert(stdout_chunks, data)
        end
    end)

    -- 读取标准错误流
    uv.read_start(stderr, function(err, data)
        if err then
            vim.schedule(function()
                vim.notify("Lint stderr 读取错误: " .. err, vim.log.levels.ERROR)
            end)
            return
        end
        if data then
            table.insert(stderr_chunks, data)
        end
    end)
end

--------------------------------------------------------------------------------
-- 解析 lint 配置，使用服务的参数解析方法
--------------------------------------------------------------------------------
--- @param config table 用户配置
--- @param context table 执行上下文
--- @return table 解析后的配置
function LintFramework.resolve_config(config, context)
    local services = context.services
    local resolver = services.resolver
    local bufnr = config.bufnr or vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)

    -- 创建解析上下文变量
    local resolve_ctx = {
        file_path = filename,
        file_dir = vim.fn.fnamemodify(filename, ":h"),
        file_name = vim.fn.fnamemodify(filename, ":t"),
        file_type = vim.bo.filetype,
        project_root = context.project_root or vim.fn.getcwd(),
    }

    -- 使用服务的 resolve_parameters 方法
    return resolver.resolve_parameters(config, resolve_ctx)
end

--------------------------------------------------------------------------------
-- 框架核心执行函数
--------------------------------------------------------------------------------
--- 执行 lint 框架，调用基础积木解析结果并发布诊断
--- @param exec_context table 框架执行上下文，由 brickdag 传入
function LintFramework.execute(exec_context)
    local logger = exec_context.services.logger -- 日志服务函数，logger(msg, level)
    local registry = exec_context.services.registry -- 积木注册表服务

    -- 解析整个配置（使用服务的 resolve_parameters 方法）
    local resolved_config = LintFramework.resolve_config(exec_context.config, exec_context)

    local bufnr = resolved_config.bufnr or vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local cmd = resolved_config.cmd
    local args = resolved_config.args

    if not cmd then
        logger("缺少 lint 命令", vim.log.levels.ERROR)
        return exec_context.on_done(false, "未指定 lint 命令")
    end

    logger("执行 lint 命令: " .. cmd .. " " .. table.concat(args or {}, " "), vim.log.levels.DEBUG)

    -- 异步执行 lint 命令
    run_lint_command(cmd, args or {}, function(stdout_data, stderr_data, code, _)
        -- 将后续处理包装到 vim.schedule 中
        vim.schedule(function()
            logger("lint stdout: " .. stdout_data, vim.log.levels.DEBUG)
            if stderr_data ~= "" then
                logger("lint stderr: " .. stderr_data, vim.log.levels.WARN)
            end
            logger("lint 退出码: " .. tostring(code), vim.log.levels.DEBUG)

            -- 通过注册表获取解析器基础积木
            local parser_brick_name = resolved_config.parser
            if not parser_brick_name or type(parser_brick_name) ~= "string" then
                logger("parser 配置必须是基础积木名称字符串", vim.log.levels.ERROR)
                return exec_context.on_done(false, "parser 配置错误")
            end

            -- 从注册表获取基础积木模块
            local parser = registry.get_base_brick(parser_brick_name)
            if not parser or type(parser.resolve) ~= "function" then
                logger("找不到合法的解析器基础积木: " .. tostring(parser_brick_name), vim.log.levels.ERROR)
                return exec_context.on_done(false, "找不到合法解析器")
            end

            -- 调用解析器基础积木的 resolve 方法，解析 lint 输出
            local ok, diagnostics_or_err = pcall(parser.resolve, { output = stdout_data }, {
                bufnr = bufnr,
                filename = filename,
                config = resolved_config,
                stderr = stderr_data,
            })

            if not ok then
                logger("解析器执行异常: " .. tostring(diagnostics_or_err), vim.log.levels.ERROR)
                return exec_context.on_done(false, tostring(diagnostics_or_err))
            end

            local diagnostics = diagnostics_or_err or {}

            -- 发布诊断信息到缓冲区
            publish_diagnostics(bufnr, diagnostics)

            -- 任务执行完成回调，标记成功
            exec_context.on_done(true)
        end)
    end)
end

return LintFramework

