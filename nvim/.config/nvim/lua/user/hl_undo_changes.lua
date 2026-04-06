local M = {}
local ns = vim.api.nvim_create_namespace("undo_hl")
local timer = nil
local prev_lines = nil

-- initial inspiration https://github.com/max397574/omega-nvim/blob/main/lua/omega/extras/highlight_undo.lua

local function get_target_buf()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local ft = vim.bo[buf].filetype
		if ft ~= "nvim-undotree" and ft ~= "undotree" and ft ~= "" then
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
	local hunks = vim.diff(table.concat(old_lines, "\n"), table.concat(new_lines, "\n"), { result_type = "indices" })
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
		vim.hl.range(buf, ns, "IncSearch", { r[1], r[2] }, { r[3], r[4] })
	end
	if timer then
		timer:stop()
	end
	timer = vim.uv.new_timer()
	timer:start(
		2000,
		0,
		vim.schedule_wrap(function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
			end
		end)
	)
end

-- Standard undo/redo via on_bytes
local active = false

vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(args)
		vim.api.nvim_buf_attach(args.buf, false, {
			on_bytes = function(
				_, -- "bytes"
				buf,
				_, -- changedtick
				sr, -- start_row
				sc, -- start_col
				_, -- start_byte
				_, -- old_end_row
				_, -- old_end_col
				_, -- old_end_byte
				ner, -- new_end_row (relative)
				nec, -- new_end_col (relative if ner == 0)
				_ -- new_end_byte
			)
				if not active then
					return
				end
				vim.schedule(function()
					if not vim.api.nvim_buf_is_valid(buf) then
						return
					end

					local end_row = sr + ner
					local end_col = (ner == 0) and (sc + nec) or nec

					pcall(vim.hl.range, buf, ns, "IncSearch", { sr, sc }, { end_row, end_col })

					if timer then
						timer:stop()
					end
					timer = vim.uv.new_timer()
					timer:start(
						300,
						0,
						vim.schedule_wrap(function()
							if vim.api.nvim_buf_is_valid(buf) then
								vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
							end
						end)
					)
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

-- Undotree
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
				vim.api.nvim_buf_clear_namespace(tbuf, ns, 0, -1)
				local new_lines = vim.api.nvim_buf_get_lines(tbuf, 0, -1, false)
				if prev_lines then
					highlight_ranges(tbuf, diff_snapshots(prev_lines, new_lines))
				end
				prev_lines = new_lines
			end,
		})
	end,
})

return M
