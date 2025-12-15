local config = {
	hl_group = "LspReferenceTarget",
	chars_lower_limit = 6,
	lines_upper_limit = 30,
	strict_spacing = false,
	buffers = "filetype",
	case_insensitive = { "markdown", "text", "help" },
}

-- Workaround for string.find() pattern complexity issue
local find2 = function(s, pattern, init, plain)
	local ok, start, stop = pcall(string.find, s, pattern, init, plain)
	if ok then
		return start, stop
	end

	local needle_length = 100
	local needle_start, any_matches = 1, false
	local match_start
	local match_stop = init and (init - 1) or nil

	local i = 0
	while needle_start < pattern:len() do
		i = i + 1
		local needle_end = needle_start + needle_length

		-- Ensure patterns don't break at certain boundaries
		local _, extra1 = pattern:find("^.?%%s%+", needle_end - 1)
		local _, extra2 = pattern:find("^[^%%]%%.", needle_end - 1)
		needle_end = extra1 or extra2 or needle_end

		local small_match_start, small_match_stop = s:find(pattern:sub(needle_start, needle_end), (match_stop or 0) + 1)

		if small_match_start then
			match_start = match_start or small_match_start
			match_stop = small_match_stop
			any_matches = true
		elseif any_matches then
			return nil, nil
		end

		needle_start = needle_end + 1
	end

	return match_start, match_stop
end

---@alias TextPoint { line: number, col: number }
---@alias TextRegion { start: TextPoint, stop: TextPoint }

---@param x string[] A table of strings; each string represents a line
---@param pattern string The pattern to match against
---@param plain boolean If `true`, special characters in `pattern` are ignored
---@return TextRegion[]
local gfind = function(x, pattern, plain)
	local x_collapsed, matches, init = table.concat(x, "\n"), {}, 0

	while true do
		local start, stop = find2(x_collapsed, pattern, init, plain)
		if start == nil then
			break
		end
		table.insert(matches, { start = start, stop = stop })
		init = stop + 1
	end

	local match_line, match_col = 1, 0

	for _, m in pairs(matches) do
		for _, type in ipairs({ "start", "stop" }) do
			local line_end = match_col + #x[match_line]
			while m[type] > line_end do
				match_col = match_col + #x[match_line] + 1
				match_line = match_line + 1
				line_end = match_col + #x[match_line]
			end
			m[type] = { line = match_line, col = m[type] - match_col }
		end
	end

	return matches
end

---@param how "all" | "current" | "filetype" | fun(buf): boolean
local get_wins = function(how)
	if how == "current" then
		return { vim.api.nvim_get_current_win() }
	elseif how == "all" then
		return vim.api.nvim_tabpage_list_wins(0)
	elseif how == "filetype" then
		return vim.tbl_filter(function(w)
			return vim.bo[vim.api.nvim_win_get_buf(w)].ft == vim.bo.ft
		end, vim.api.nvim_tabpage_list_wins(0))
	elseif type(how) == "function" then
		return vim.tbl_filter(function(w)
			return how(vim.api.nvim_win_get_buf(w)) and true or false
		end, vim.api.nvim_tabpage_list_wins(0))
	end
	error(("Invalid input for `how`: `%s`"):format(vim.inspect(how)))
end

local is_case_insensitive = function(ft1, ft2)
	if type(config.case_insensitive) == "boolean" then
		return config.case_insensitive
	end
	if type(config.case_insensitive) == "table" then
		for _, special_ft in ipairs(config.case_insensitive) do
			if ft1 == special_ft or ft2 == special_ft then
				return true
			end
		end
	end
	return false
end

local match_ns = vim.api.nvim_create_namespace("visimatch")
local augroup = vim.api.nvim_create_augroup("visimatch", { clear = true })

vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
	group = augroup,
	callback = function()
		local wins = get_wins(config.buffers)
		for _, win in pairs(wins) do
			vim.api.nvim_buf_clear_namespace(vim.api.nvim_win_get_buf(win), match_ns, 0, -1)
		end

		local mode = vim.fn.mode()
		if mode ~= "v" and mode ~= "V" then
			return
		end

		local selection_start, selection_stop = vim.fn.getpos("v"), vim.fn.getpos(".")
		local selection = vim.fn.getregion(selection_start, selection_stop, { type = mode })
		local selection_collapsed = vim.trim(table.concat(selection, "\n"))
		local selection_buf = vim.api.nvim_get_current_buf()

		if #selection > config.lines_upper_limit then
			return
		end
		if #selection_collapsed < config.chars_lower_limit then
			return
		end

		local pattern = selection_collapsed:gsub("(%p)", "%%%0")
		if not config.strict_spacing then
			pattern = pattern:gsub("%s+", "%%s+")
		end
		local pattern_lower

		for _, win in pairs(wins) do
			local first_line = vim.fn.line("w0", win) - 1
			local last_line = vim.fn.line("w$", win)
			local buf = vim.api.nvim_win_get_buf(win)
			local visible_text = vim.api.nvim_buf_get_lines(buf, first_line, last_line, false)
			local case_insensitive = is_case_insensitive(vim.bo[buf].ft, vim.bo.ft)

			if case_insensitive and not pattern_lower then
				pattern_lower = pattern:lower()
			end

			local needle = case_insensitive and pattern_lower or pattern
			local haystack = case_insensitive and vim.tbl_map(string.lower, visible_text) or visible_text
			local matches = gfind(haystack, needle, false)

			for _, m in pairs(matches) do
				m.start.line, m.stop.line = m.start.line + first_line, m.stop.line + first_line

				-- Ensure matches are after the selection region
				local m_starts_after_selection = m.start.line > selection_stop[2]
					or (m.start.line == selection_stop[2] and m.start.col > selection_stop[3])

				local m_ends_before_selection = m.stop.line < selection_start[2]
					or (m.stop.line == selection_start[2] and m.stop.col < selection_start[3])

				if buf ~= selection_buf or m_starts_after_selection or m_ends_before_selection then
					for line = m.start.line, m.stop.line do
						vim.hl.range(
							buf, -- Buffer ID
							match_ns, -- Namespace ID
							config.hl_group, -- Highlight group
							{ line - 1, line == m.start.line and m.start.col - 1 or 0 }, -- Start position (line, col)
							{
								line == m.stop.line and m.stop.line - 1 or line - 1,
								line == m.stop.line and m.stop.col or -1,
							}, -- End position
							{ inclusive = false } -- Optional extra setting for whether to include the end position
						)
					end
				end
			end
		end
	end,
})
