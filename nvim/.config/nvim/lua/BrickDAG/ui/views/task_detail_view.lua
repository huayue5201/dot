-- BrickDAG/ui/views/task_detail_view.lua

local M = {}

--- 渲染任务详情界面
--- @param bufnr integer buffer 编号
--- @param ctx table 渲染上下文（含 win, name, type, data 等）
function M.render(bufnr, ctx)
	local task = ctx.data or {}
	local lines = {}

	table.insert(lines, "📌 任务名称: " .. (task.name or "(未命名)"))
	table.insert(lines, "类型: " .. (task.type or "(未知)"))
	table.insert(lines, "")
	table.insert(lines, "🔧 参数:")

	local args = task[task.type] or {}
	for k, v in pairs(args) do
		local val = type(v) == "table" and vim.inspect(v) or tostring(v)
		table.insert(lines, string.format("  • %s = %s", k, val))
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].bufhidden = "wipe"
end

return M
