-- lua/lsp-config/copy_diagnostics/init.lua
---@brief 复制当前行诊断（附带 Treesitter AST 上下文，AI 友好）
local format = require("lsp-config.copy_diagnostics.format")
local ast = require("lsp-config.copy_diagnostics.ast")
local M = {}

function M.copy_error_message()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local row = cursor_pos[1] - 1
	local bufnr = vim.api.nvim_get_current_buf()

	local diagnostics = vim.diagnostic.get(bufnr, { lnum = row })

	if #diagnostics == 0 then
		vim.notify("No diagnostics found at current line", vim.log.levels.WARN)
		return
	end

	table.sort(diagnostics, function(a, b)
		return a.severity < b.severity
	end)

	local get_ast = ast.create_cache(bufnr)

	-- 单条诊断
	if #diagnostics == 1 then
		local d = diagnostics[1]
		local content = string.format("%s\n\n%s", format.single(d), get_ast(d))

		vim.fn.setreg("+", content)
		vim.fn.setreg('"', content)
		vim.notify("Copied diagnostic with AST context", vim.log.levels.INFO)
		return
	end

	---------------------------------------------------------
	-- 多条诊断：构建选择菜单
	---------------------------------------------------------
	local choices = {}
	local choice_map = {}

	for _, d in ipairs(diagnostics) do
		table.insert(choices, format.preview(d))
		choice_map[#choices] = { type = "single", data = d }
	end

	local groups = format.group_by_type(diagnostics)
	for _, group in pairs(groups) do
		if group.count > 1 then
			table.insert(choices, format.group_preview(group))
			choice_map[#choices] = { type = "group", data = group }
		end
	end

	table.insert(choices, "📋 Copy all diagnostics")
	choice_map[#choices] = { type = "all", data = diagnostics }

	vim.ui.select(choices, {
		prompt = "Select diagnostics to copy:",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if not choice or not idx then
			return
		end

		local selected = choice_map[idx]
		local content = ""

		if selected.type == "all" then
			local lines = {}
			for _, d in ipairs(selected.data) do
				table.insert(lines, format.single(d) .. "\n\n" .. get_ast(d))
			end
			content = table.concat(lines, "\n\n====================\n\n")
		elseif selected.type == "group" then
			local group = selected.data
			local lines = {}

			table.insert(lines, string.format("=== %s (%d messages) ===", group.code or "No code", group.count))

			for _, d in ipairs(diagnostics) do
				if d.code == group.code then
					table.insert(lines, format.single(d) .. "\n\n" .. get_ast(d))
				end
			end

			content = table.concat(lines, "\n\n--------------------\n\n")
		elseif selected.type == "single" then
			local d = selected.data
			content = format.single(d) .. "\n\n" .. get_ast(d)
		end

		if content and content ~= "" then
			vim.fn.setreg("+", content)
			vim.fn.setreg('"', content)
			vim.notify("Copied diagnostic with AST context", vim.log.levels.INFO)
		end
	end)
end

return M
