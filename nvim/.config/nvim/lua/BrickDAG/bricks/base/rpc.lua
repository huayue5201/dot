local uv = vim.loop

local M = {
    name = "rpc",
    brick_type = "base",
    description = "跨进程通信积木（支持 gRPC/WebSocket/HTTP）",
    protocols = {}, -- 协议处理器注册表
}

-- 注册协议处理器
function M.register_protocol(name, handler)
    M.protocols[name] = handler
end

-- 核心解析方法
function M.resolve(config, context)
    local protocol = config.protocol or "http"
    local handler = M.protocols[protocol]

    if not handler then
        error("不支持的协议: " .. protocol)
    end

    -- 返回可执行的RPC函数
    return function(params)
        -- 1. 合并配置参数与运行时参数
        local merged = vim.tbl_deep_extend("force", config, params or {})

        -- 2. 执行协议处理器
        local ok, result = pcall(handler, merged, context)

        if not ok then
            return nil, result
        end
        return result
    end
end

-- 内置HTTP处理器
M.register_protocol("http", function(config)
    local url = config.url
    local method = config.method or "GET"
    local headers = config.headers or {}
    local body = config.body

    return uv.new_work(function()
        -- 实际HTTP请求逻辑
        local http = require("brickdag.utils.http")
        return http.request(method, url, headers, body)
    end)
end)

-- 内置gRPC处理器（需安装grpc-lua）
M.register_protocol("grpc", function(config)
    local service = config.service
    local method = config.method
    local request = config.request

    return uv.new_work(function()
        local grpc = require("grpc")
        local client = grpc.client(service)
        return client[method](request)
    end)
end)

-- 内置WebSocket处理器
M.register_protocol("websocket", function(config)
    local url = config.url
    local message = config.message

    return uv.new_work(function()
        local ws = require("brickdag.utils.websocket")
        local conn = ws.connect(url)
        conn:send(message)
        return conn:receive()
    end)
end)

return M

