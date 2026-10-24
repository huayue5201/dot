-- File: nvim/.config/nvim/lua/lib/cargo.lua
---@brief cargo 的 `--message-format=json` 消息流 → 统一结构化结果（lib.tool 的 adapter）
---
--- 只负责「cargo 语法」，输出怎么给用户看由 lib/tool 决定。

local tool = require("lib.tool")

local M = {}

---@type ToolDiagnostic[]
local function to_diagnostic(m)
	local span = m.spans and m.spans[1]
	if not span or not span.file_name then
		return nil
	end
	return {
		filename = span.file_name,
		lnum = span.line_start or 1,
		col = span.column_start or 1,
		end_lnum = span.line_end,
		end_col = span.column_end,
		severity = m.level == "error" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
		message = m.message or "",
	}
end

--- 纯解析：JSON 消息流 → 产物路径 + 诊断
---@param stdout string
---@return { diagnostics: ToolDiagnostic[], data: { artifacts: string[] } }
local function parse(stdout)
	local artifacts, diagnostics, seen = {}, {}, {}
	for _, line in ipairs(vim.split(stdout, "\r?\n")) do
		if line ~= "" then
			local ok, msg = pcall(vim.json.decode, line)
			if ok and type(msg) == "table" then
				if msg.reason == "compiler-artifact" and msg.executable and msg.target then
					local kind = msg.target.kind or {}
					if vim.list_contains(kind, "bin") or (msg.profile and msg.profile.test) then
						artifacts[#artifacts + 1] = msg.executable
					end
				elseif msg.reason == "compiler-message" and msg.message then
					local d = to_diagnostic(msg.message)
					if d then
						local key = ("%s:%d:%d:%s"):format(d.filename, d.lnum, d.col, d.message)
						if not seen[key] then
							seen[key] = true
							diagnostics[#diagnostics + 1] = d
						end
					end
				end
			end
		end
	end
	return { diagnostics = diagnostics, data = { artifacts = artifacts } }
end

---@param cmd string[]
---@param opts table|nil { cwd, env, timeout }
---@param cb fun(res: ToolResult)|nil
---@return ToolResult|nil
function M.run(cmd, opts, cb)
	return tool.run(cmd, vim.tbl_extend("force", { parser = parse }, opts or {}), cb)
end

--- 跑构建，失败时按统一策略提示，返回可执行文件路径
---@param cmd string[]
---@param opts table|nil
---@return string[]
function M.get(cmd, opts)
	local res = M.run(cmd, opts)
	tool.report(res, "cargo")
	return (res.ok and res.data and res.data.artifacts) or {}
end

return M
