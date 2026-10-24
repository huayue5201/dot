-- lua/lib/lsp_request.lua
--[[
LSP 单请求 + 超时（内部共享库）
==============================
`client:request` 本身没有超时：server 不回包时回调永远不会触发，调用方只能干等。
这里统一三条约定：

  1) 幂等：回包与超时谁先到都只回调一次
  2) 主循环：回调一律 `vim.schedule`，可以安全地改 buffer/window
  3) 不泄漏：定时器在结果到达时立即 stop+close

    require("lib.lsp_request").request(client, "textDocument/hover", params, {
      bufnr = 0, timeout = 1500, what = "hover", notify = true,
    }, function(result, err) ... end)

批量扇出（N 个 client × M 个 resolve）语义不同，见 lsp_ext/features/code_lens.lua。
]]
local M = {}

local defaults = {
	timeout = 1500, -- 毫秒；<= 0 表示不设超时
}

---@param opts { timeout?: integer }
function M.setup(opts)
	defaults = vim.tbl_extend("force", defaults, opts or {})
end

-- LSP 的错误是 { code, message } 表，直接 tostring 会变成 "table: 0x..."
local function describe(err)
	if type(err) == "table" then
		return err.message or vim.inspect(err)
	end
	return tostring(err)
end

local function kill(timer)
	if not timer then
		return
	end
	pcall(timer.stop, timer)
	if not timer:is_closing() then
		pcall(timer.close, timer)
	end
end

--- 发一个 LSP 请求，cb(result, err) 保证在主循环里、且只调用一次
---@param client vim.lsp.Client
---@param method string
---@param params table
---@param opts { bufnr?: integer, timeout?: integer, what?: string, notify?: boolean }|nil 省略时第三个参数可以是 cb
---@param cb fun(result: any, err: string|nil)
function M.request(client, method, params, opts, cb)
	if type(opts) == "function" then
		opts, cb = {}, opts
	end
	opts = opts or {}

	local timeout = opts.timeout or defaults.timeout
	local settled, timer = false, nil

	local function finish(result, err)
		if settled then
			return
		end
		settled = true
		kill(timer)
		timer = nil

		if err and opts.notify then
			local label = opts.what or method
			if err == "timeout" then
				vim.notify(string.format("[lsp] %s 超时（%dms）", label, timeout), vim.log.levels.WARN)
			else
				vim.notify(string.format("[lsp] %s 失败: %s", label, describe(err)), vim.log.levels.ERROR)
			end
		end
		cb(result, err)
	end

	if timeout and timeout > 0 then
		timer = vim.defer_fn(function()
			finish(nil, "timeout")
		end, timeout)
	end

	local ok, err = pcall(client.request, client, method, params, function(res_err, result)
		vim.schedule(function()
			finish(result, res_err)
		end)
	end, opts.bufnr)
	if not ok then
		finish(nil, err)
	end
end

return M
