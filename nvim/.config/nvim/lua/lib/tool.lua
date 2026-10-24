-- File: nvim/.config/nvim/lua/lib/tool.lua
---@brief 跑外部工具，并把它的输出挡在 UI 之外
---
--- 设计约束（改动前先读）：
---   * `run()` 只返回结构化数据（`ToolResult`），里面**没有原始文本字段**，
---     所以调用方拿不到料去刷屏 —— 约束落在数据形状上，不靠自觉。
---   * 原始 stdout/stderr 只进下面的 history，唯一出口是用户显式 `:ToolLog`。
---   * 唯一允许提示用户的地方是 `M.report()`：只说计数，不拼工具输出。
---   * 工具自己的输出靠 `opts.parser` 转成统一形状（与 `vim.diagnostic` 同形），
---     具体工具的 JSON 语法留在各自的 adapter 里（见 lib/cargo.lua）。

local M = {}

---@alias ToolDiagnostic { filename: string, lnum: integer, col: integer, end_lnum: integer|nil, end_col: integer|nil, severity: integer, message: string }

---@class ToolResult
---@field ok boolean
---@field code integer
---@field diagnostics ToolDiagnostic[]
---@field data table|nil parser 的附加产物（例如 cargo 产物路径）

--- 保留最近几次运行的原始输出
local MAX_RUNS = 5
---@type { cmd: string, lines: string[] }[]
local history = {}
local command_created = false

---@param s string|nil
---@return string[]
local function split_lines(s)
	local out = {}
	for line in (s or ""):gmatch("[^\r\n]+") do
		out[#out + 1] = line
	end
	return out
end

local function ensure_command()
	if command_created then
		return
	end
	command_created = true
	vim.api.nvim_create_user_command("ToolLog", function()
		M.open_log()
	end, { desc = "查看最近几次外部工具的原始输出" })
end

--- 原始输出只进这里，不进 UI
local function remember(cmd, sc)
	local lines = { "$ " .. table.concat(cmd, " ") }
	for _, line in ipairs(split_lines(sc.stdout)) do
		lines[#lines + 1] = "  " .. line
	end
	for _, line in ipairs(split_lines(sc.stderr)) do
		lines[#lines + 1] = "! " .. line
	end
	history[#history + 1] = { cmd = table.concat(cmd, " "), lines = lines }
	if #history > MAX_RUNS then
		table.remove(history, 1)
	end
end

---@param cmd string[]
---@param opts table
---@param sc table vim.system 的 SystemCompleted
---@return ToolResult
local function collect(cmd, opts, sc)
	remember(cmd, sc)
	local res = { ok = sc.code == 0, code = sc.code, diagnostics = {}, data = nil }
	if opts.parser then
		local ok, parsed = pcall(opts.parser, sc.stdout or "")
		if ok and parsed then
			res.diagnostics = parsed.diagnostics or {}
			res.data = parsed.data
		end
	end
	return res
end

--- 跑命令。给了 cb 就异步（cb 拿 ToolResult），否则同步返回 ToolResult。
---@param cmd string[]
---@param opts table|nil { cwd, env, timeout, parser = fun(stdout: string): { diagnostics: ToolDiagnostic[], data: table|nil } }
---@param cb fun(res: ToolResult)|nil
---@return ToolResult|nil
function M.run(cmd, opts, cb)
	ensure_command()
	opts = opts or {}
	local sys_opts = { text = true, cwd = opts.cwd, env = opts.env, timeout = opts.timeout }
	if cb then
		vim.system(cmd, sys_opts, function(sc)
			vim.schedule(function()
				cb(collect(cmd, opts, sc))
			end)
		end)
		return nil
	end
	return collect(cmd, opts, vim.system(cmd, sys_opts):wait())
end

--- 把结构化诊断交给 vim.diagnostic（每个 label 一个 namespace，每次覆盖）。
--- 同一行已经有别的来源的诊断时跳过，避免和 LSP/flycheck 叠加成两片。
---@param res ToolResult
---@param label string
local function publish(res, label)
	local ns = vim.api.nvim_create_namespace("tool:" .. label)
	vim.diagnostic.reset(ns)
	local by_buf = {}
	for _, d in ipairs(res.diagnostics) do
		local buf = vim.fn.bufnr(d.filename)
		if buf == -1 then
			buf = vim.fn.bufadd(d.filename)
		end
		-- 只往已经打开的 buffer 上贴，不为了诊断去加载文件
		if vim.fn.bufloaded(buf) == 1 then
			local taken = false
			for _, other in ipairs(vim.diagnostic.get(buf, { lnum = d.lnum - 1 })) do
				if other.namespace ~= ns and other.severity == d.severity then
					taken = true
					break
				end
			end
			if not taken then
				by_buf[buf] = by_buf[buf] or {}
				table.insert(by_buf[buf], d)
			end
		end
	end
	for buf, items in pairs(by_buf) do
		vim.diagnostic.set(ns, buf, items)
	end
end

--- 唯一允许提示用户的地方：只说计数。
---@param res ToolResult
---@param label string 工具名，用于提示和 namespace
function M.report(res, label)
	if res.ok then
		return
	end
	if #res.diagnostics == 0 then
		vim.notify(
			("%s 失败（exit %d），没有结构化诊断（原始输出 :ToolLog）"):format(label, res.code),
			vim.log.levels.ERROR
		)
		return
	end
	publish(res, label)
	local nerr = 0
	for _, d in ipairs(res.diagnostics) do
		if d.severity == vim.diagnostic.severity.ERROR then
			nerr = nerr + 1
		end
	end
	vim.notify(
		("%s 失败：%d 个错误、%d 条诊断（原始输出 :ToolLog）"):format(label, nerr, #res.diagnostics),
		vim.log.levels.ERROR
	)
end

--- 打开最近几次运行的原始输出（scratch buffer，不落盘）
function M.open_log()
	local lines = {}
	for i, entry in ipairs(history) do
		if i > 1 then
			lines[#lines + 1] = ""
		end
		vim.list_extend(lines, entry.lines)
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "tool-log"
	vim.api.nvim_buf_set_name(buf, "tool://log")
	vim.api.nvim_win_set_buf(0, buf)
end

return M
