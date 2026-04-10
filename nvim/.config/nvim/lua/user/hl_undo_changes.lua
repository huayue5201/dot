local NS = vim.api.nvim_create_namespace("undo_hl")
local HL_GROUP = "IncSearch"
local TIMEOUT_MS = 300
local prev_lines = nil

local function get_target_buf()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.bo[buf].filetype
		if ft ~= "nvim-undotree" and ft ~= "" then
			return buf
		end
	end
end

local function get_char_diff(old_str, new_str)
	local s = 1
	local min_len = math.min(#old_str, #new_str)
	while s <= min_len and old_str:sub(s, s) == new_str:sub(s, s) do
		s = s + 1
	end
	if s > #old_str and s > #new_str then
		return nil
	end
	local oe, ne = #old_str, #new_str
	while oe >= s and ne >= s and old_str:sub(oe, oe) == new_str:sub(ne, ne) do
		oe = oe - 1
		ne = ne - 1
	end
	return s - 1, ne
end

local function diff_snapshots(old_lines, new_lines)
	local ranges = {}
	local hunks =
		vim.text.diff(table.concat(old_lines, "\n"), table.concat(new_lines, "\n"), { result_type = "indices" })

	if type(hunks) ~= "table" then
		return ranges
	end

	for _, hunk in ipairs(hunks) do
		local sa, ca, sb, cb = hunk[1], hunk[2], hunk[3], hunk[4]
		if cb > 0 then
			local row = sb - 1
			if ca == cb then
				for i = 0, cb - 1 do
					local cs, ce = get_char_diff(old_lines[sa + i] or "", new_lines[sb + i] or "")
					if cs then
						if cs == ce then
							ce = cs + 1
						end
						table.insert(ranges, { row + i, cs, row + i, ce })
					end
				end
			else
				for i = 0, cb - 1 do
					table.insert(ranges, { row + i, 0, row + i, -1 })
				end
			end
		end
	end
	return ranges
end

local function highlight_ranges(buf, ranges)
	for _, r in ipairs(ranges) do
		vim.hl.range(buf, NS, HL_GROUP, { r[1], r[2] }, { r[3], r[4] }, { timeout = TIMEOUT_MS })
	end
end

local active = false

vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(args)
		vim.api.nvim_buf_attach(args.buf, false, {
			on_bytes = function(_, buf, _, sr, sc, _, _, _, _, er, ec)
				if not active then
					return
				end
				vim.schedule(function()
					if not vim.api.nvim_buf_is_valid(buf) then
						return
					end
					local end_col = sc + ec
					if er == 0 and ec == 0 then
						end_col = sc + 1
					end
					pcall(vim.hl.range, buf, NS, HL_GROUP, { sr, sc }, { sr + er, end_col }, { timeout = TIMEOUT_MS })
				end)
			end,
		})
	end,
})

local function run(cmd)
	active = true
	vim.cmd(cmd)
	vim.defer_fn(function()
		active = false
	end, 50)
end

vim.keymap.set("n", "u", function()
	run("undo")
end)
vim.keymap.set("n", "<C-r>", function()
	run("redo")
end)

vim.api.nvim_create_autocmd("FileType", {
	pattern = "nvim-undotree",
	callback = function(args)
		vim.api.nvim_create_autocmd("BufEnter", {
			buffer = args.buf,
			callback = function()
				local tbuf = get_target_buf()
				if tbuf then
					prev_lines = vim.api.nvim_buf_get_lines(tbuf, 0, -1, false)
				end
			end,
		})
		vim.api.nvim_create_autocmd("CursorMoved", {
			buffer = args.buf,
			callback = function()
				local tbuf = get_target_buf()
				if not tbuf then
					return
				end
				local new_lines = vim.api.nvim_buf_get_lines(tbuf, 0, -1, false)
				if prev_lines then
					highlight_ranges(tbuf, diff_snapshots(prev_lines, new_lines))
				end
				prev_lines = new_lines
			end,
		})
	end,
})
