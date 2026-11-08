-- 项目概览：给 AI 的紧凑摘要（~300 字，只有结构与统计，不含源码）
local M = {}

----------------------------------------------------------------------
-- 给 AI 的紧凑摘要（digest）
----------------------------------------------------------------------

-- 阅读契约：摘要里带一句，省得每次提问都重复交代，也防止 agent 先去全库乱搜
local ASK_CONTRACT =
	"answer_from_digest: answer structure/scale/ownership questions based only on this digest; for anything the digest does not cover, first list the files and line ranges to read instead of exploring the whole repo with find/grep"

--- 粗略 token 估算：ASCII 约 4 字符/token，中文约 1 字符/token
---@param text string
---@return integer
local function est_tokens(text)
	local bytes = #text
	local chars = vim.fn.strchars(text)
	local cjk = math.max(0, (bytes - chars) / 2)
	return math.ceil(cjk + (chars - cjk) / 4)
end

--- 把 data 压成 300~400 token 的「索引式」摘要：每行一类事实，路径原样，不带易变时间戳
---@param data table
---@return string
local function digest(data)
	local L = {}
	local head = { "PROJECT", data.name }
	if data.git then
		head[#head + 1] = "@ " .. (data.head or "?")
		if data.dirty > 0 then
			head[#head + 1] = ("dirty=%d"):format(data.dirty)
		end
	end
	L[#L + 1] = table.concat(head, " ")

	local root = { "root", data.root, data.git and "git" or "no-git" }
	if data.git then
		root[#root + 1] = "branch=" .. (data.branch or "?")
		root[#root + 1] = "last_commit=" .. (data.date or "?")
		if #data.tags > 0 then
			root[#root + 1] = ("tags=%d"):format(#data.tags)
		end
	end
	if data.license then
		root[#root + 1] = "license=" .. data.license
	end
	L[#L + 1] = table.concat(root, " ")

	-- source 用英文短标签：中文进摘要只会多花 token
	local stats_tag = data.source:find("tokei", 1, true) and "tokei(code only)" or "wc(all lines)"
	L[#L + 1] = ("scale code_lines=%d files=%d stats=%s"):format(data.code, #data.files, stats_tag)

	if #data.langs > 0 then
		local parts = {}
		for _, lang in ipairs(vim.list_slice(data.langs, 1, 5)) do
			if lang.code > 0 then
				parts[#parts + 1] = ("%s:%d"):format(lang.name, lang.code)
			end
		end
		L[#L + 1] = "langs " .. table.concat(parts, " ")
	end

	if #data.structure > 0 then
		local parts = {}
		for _, d in ipairs(vim.list_slice(data.structure, 1, 8)) do
			parts[#parts + 1] = ("%s %df/%dL"):format(d.path or d.name, d.files, d.lines)
		end
		L[#L + 1] = "dirs " .. table.concat(parts, " | ")
	end

	if #data.big > 0 then
		local parts = {}
		for _, f in ipairs(vim.list_slice(data.big, 1, 5)) do
			parts[#parts + 1] = ("%s %dL"):format(f.path, f.lines)
		end
		L[#L + 1] = "biggest " .. table.concat(parts, " | ")
	end

	if data.git and #data.active > 0 then
		local parts = {}
		for _, f in ipairs(vim.list_slice(data.active, 1, 5)) do
			parts[#parts + 1] = ("%s %dx"):format(f.path, f.count)
		end
		L[#L + 1] = "hot_90d_commits " .. table.concat(parts, " | ")
	end

	if #data.build > 0 then
		L[#L + 1] = "build " .. table.concat(vim.list_slice(data.build, 1, 3), " ; ")
	end
	if #data.deps > 0 then
		local parts = {}
		for _, dep in ipairs(vim.list_slice(data.deps, 1, 2)) do
			parts[#parts + 1] = ("%s=%s"):format(dep.label, table.concat(vim.list_slice(dep.list, 1, 6), ","))
		end
		L[#L + 1] = "deps " .. table.concat(parts, " ; ")
	end

	local misc = { ("tests=%d/%d"):format(data.tests, #data.files) }
	if data.todo > 0 then
		misc[#misc + 1] = ("todo_fixme=%d"):format(data.todo)
	end
	if #data.conventions > 0 then
		misc[#misc + 1] = "conventions=" .. #data.conventions
	end
	L[#L + 1] = table.concat(misc, " ")

	L[#L + 1] = "NOT_INCLUDED source code (this digest contains only structure and stats, no source)"
	L[#L + 1] = ASK_CONTRACT
	return table.concat(L, "\n")
end

--- 把一份概览 data 渲染成给 AI 的摘要（公开：其它模块/MCP 可直接调用）
---@param data table
---@return string text
---@return integer tokens 粗略估算
function M.digest(data)
	local text = digest(data)
	return text, est_tokens(text)
end

return M
