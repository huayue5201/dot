-- BrickDAG/ui/views/eval_result_view.lua

local M = {}

--- 将 Lua table 美化为多行字符串（简化版）
local function format_result(data, indent)
	indent = indent or 0
	local prefix = string.rep("  ", indent)
	local lines = {}

	if type(data) ~= "table" then
		table.insert(lines, prefix .. vim.inspect(data))
		return lines
	end

	table.insert(lines, prefix .. "{")
	for k, v in pairs(data) do
		local key = tostring(k)
		if type(v) == "table" then
			table.insert(lines, prefix .. "  " .. key .. " = ")
			vim.list_extend(lines, format_result(v, indent + 2))
		else
			local val = vim.inspect(v)
			table.insert(lines, prefix .. "  " .. key .. " = " .. val)
		end
	end
	table.insert(lines, prefix .. "}")
	return lines
end

--- 渲染右窗结果
function M.render(bufnr, ctx)
	local result = ctx.data or {}

	local lines = { "📦 执行结果:", "" }

	if type(result) == "string" then
		table.insert(lines, result)
	elseif result == nil or vim.tbl_isempty(result) then
		table.insert(lines, "⚠️ 无结果")
	else
		local body = format_result(result)
		vim.list_extend(lines, body)
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].bufhidden = "wipe"
end

return M
