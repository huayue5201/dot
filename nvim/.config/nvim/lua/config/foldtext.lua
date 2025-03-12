local lsp_icons = require("config.utils").icons.diagnostic

local M = {}

local function replace_tabs_with_spaces(line)
	local col = 0
	return line:gsub("\t", function()
		local spaces = vim.o.tabstop - (col % vim.o.tabstop)
		col = col + spaces
		return (" "):rep(spaces)
	end)
end

local function get_fold_diagnostics(start_lnum, end_lnum)
	local diagnostics = vim.diagnostic.get(0)
	local counts = { 0, 0, 0, 0 } -- ERROR, WARN, HINT, INFO
	local severity_map = { "ERROR", "WARN", "HINT", "INFO" }

	for _, diag in ipairs(diagnostics) do
		if diag.lnum >= start_lnum and diag.lnum <= end_lnum then
			counts[diag.severity] = counts[diag.severity] + 1
		end
	end
	for severity, count in ipairs(counts) do
		if count > 0 then
			return string.format("  %s %d ", lsp_icons[severity_map[severity]], count),
				"DiagnosticSign" .. severity_map[severity]
		end
	end
	return "", ""
end

local function fold_virt_text(result, s, lnum, coloff)
	local text, hl = "", "Normal"
	coloff = coloff or 0

	for i = 1, #s do
		local char = s:sub(i, i)
		local hls = vim.treesitter.get_captures_at_pos(0, lnum, coloff + i - 1)
		local new_hl = "@" .. (hls[1] and hls[1].capture or "Normal")

		if new_hl ~= hl then
			if #text > 0 then
				table.insert(result, { text, hl })
			end
			text, hl = char, new_hl
		else
			text = text .. char
		end
	end

	if #text > 0 then
		table.insert(result, { text, hl })
	end
end

function M.custom_foldtext()
	local start_lnum, end_lnum = vim.v.foldstart - 1, vim.v.foldend - 1
	local result = {}

	fold_virt_text(result, replace_tabs_with_spaces(vim.fn.getline(vim.v.foldstart)), start_lnum)
	table.insert(result, { " … ", "Delimiter" })

	local diag_text, diag_hl = get_fold_diagnostics(start_lnum, end_lnum)
	if diag_text ~= "" then
		table.insert(result, { diag_text, diag_hl })
	end

	table.insert(result, { string.format("   %d lines ", vim.v.foldend - vim.v.foldstart + 1), "Delimiter" })

	return result
end

return M
