-- lua/local/ai/message.lua
---@brief 把「问题 + 锚点」渲染成最终发出去的文本。
--
-- 渲染放在 nvim 侧（而不是各个 agent 的适配层里），这样所有后端拿到的是同一种
-- 消息格式，换 agent 不用重写一遍拼装逻辑。格式与 pi 扩展早期的 renderAsk 一致，
-- 老版本 pi 扩展仍能解析 {prompt, anchor} 这种旧 payload。

local M = {}

---@param anchor table
---@param prompt string
---@return string
function M.render(anchor, prompt)
	local a = anchor or {}
	local question = vim.trim(prompt or "")
	local out = { question ~= "" and question or "(空问题)" }

	local where = {
		a.path and ("%s:%d"):format(a.path, a.line or 1) or "<无文件名>",
		a.tab and ("tab %d"):format(a.tab) or nil,
		a.modified and "未保存" or nil,
	}
	local bits = {}
	for _, w in ipairs(where) do
		if w then
			table.insert(bits, w)
		end
	end

	table.insert(out, "")
	table.insert(out, ("<nvim-context %s>"):format(table.concat(bits, " · ")))
	if a.cwd then
		table.insert(out, "cwd: " .. a.cwd)
	end
	if a.visual then
		table.insert(out, ("selection %d-%d:"):format(a.visual.start_line, a.visual.end_line))
		table.insert(out, "```" .. (a.filetype or ""))
		for _, line in ipairs(a.visual.lines or {}) do
			table.insert(out, line)
		end
		table.insert(out, "```")
	end
	table.insert(out, "</nvim-context>")
	return table.concat(out, "\n")
end

return M
