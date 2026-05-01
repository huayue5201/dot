local M = {}

local NS = vim.api.nvim_create_namespace("undo_hl")
local HL_GROUP = "IncSearch"
local TIMEOUT_MS = 300

-- state[bufnr] = {
--   active = false,
--   attached = true,
--   prev_lines = nil,
--   timer = uv_timer,
-- }
local state = {}

local function get_state(buf)
	local s = state[buf]
	if not s then
		s = {
			active = false,
			attached = false,
			prev_lines = nil,
			timer = nil,
		}
		state[buf] = s
	end
	return s
end

local function clear_state(buf)
	local s = state[buf]
	if not s then
		return
	end
	if s.timer then
		s.timer:stop()
		s.timer:close()
		s.timer = nil
	end
	state[buf] = nil
end

local function is_real_file(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	if not vim.bo[buf].buflisted then
		return false
	end
	if vim.bo[buf].buftype ~= "" then
		return false
	end
	if vim.bo[buf].filetype == "nvim-undotree" then
		return false
	end
	return true
end

local function get_target_buf()
	local current = vim.api.nvim_get_current_win()

	-- Prefer alternate windows first
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if win ~= current then
			local buf = vim.api.nvim_win_get_buf(win)
			if is_real_file(buf) then
				return buf
			end
		end
	end

	-- Fallback: any valid normal buffer
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if is_real_file(buf) then
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
					local old = old_lines[sa + i] or ""
					local new = new_lines[sb + i] or ""
					local cs, ce = get_char_diff(old, new)

					if cs then
						if cs == ce then
							ce = cs + 1
						end
						ranges[#ranges + 1] = { row + i, cs, row + i, ce }
					end
				end
			else
				for i = 0, cb - 1 do
					ranges[#ranges + 1] = { row + i, 0, row + i, -1 }
				end
			end
		end
	end

	return ranges
end

local function highlight_ranges(buf, ranges)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	for _, r in ipairs(ranges) do
		pcall(vim.hl.range, buf, NS, HL_GROUP, { r[1], r[2] }, { r[3], r[4] }, {
			timeout = TIMEOUT_MS,
		})
	end
end

local function attach(buf)
	local s = get_state(buf)
	if s.attached or not is_real_file(buf) then
		return
	end

	s.attached = true

	vim.api.nvim_buf_attach(buf, false, {
		on_detach = function(_, b)
			clear_state(b)
		end,

		on_bytes = function(_, b, _, sr, sc, _, _, _, _, er, ec)
			local st = state[b]
			if not st or not st.active then
				return
			end

			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(b) then
					return
				end

				local end_col = sc + ec
				if er == 0 and ec == 0 then
					end_col = sc + 1
				end

				pcall(vim.hl.range, b, NS, HL_GROUP, { sr, sc }, { sr + er, end_col }, {
					timeout = TIMEOUT_MS,
				})
			end)
		end,
	})
end

local function run(buf, cmd)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local s = get_state(buf)
	s.active = true

	vim.api.nvim_win_call(vim.fn.bufwinid(buf), function()
		vim.cmd(cmd)
	end)

	vim.schedule(function()
		if state[buf] then
			state[buf].active = false
		end
	end)
end

function M.undo()
	local buf = vim.api.nvim_get_current_buf()
	attach(buf)
	run(buf, "undo")
end

function M.redo()
	local buf = vim.api.nvim_get_current_buf()
	attach(buf)
	run(buf, "redo")
end

local function debounce(buf, fn, ms)
	local s = get_state(buf)

	if s.timer then
		s.timer:stop()
		s.timer:close()
	end

	s.timer = vim.uv.new_timer()
	s.timer:start(ms, 0, function()
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(buf) then
				fn()
			end
		end)
	end)
end

function M.setup(opts)
	opts = opts or {}
	HL_GROUP = opts.hl_group or HL_GROUP
	TIMEOUT_MS = opts.timeout or TIMEOUT_MS

	vim.keymap.set("n", "u", M.undo, { desc = "Undo with highlight" })
	vim.keymap.set("n", "<C-r>", M.redo, { desc = "Redo with highlight" })

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWinEnter" }, {
		callback = function(args)
			if is_real_file(args.buf) then
				attach(args.buf)
			end
		end,
	})

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "nvim-undotree",
		callback = function(args)
			vim.api.nvim_create_autocmd("BufEnter", {
				buffer = args.buf,
				callback = function()
					local tbuf = get_target_buf()
					if not tbuf then
						return
					end
					attach(tbuf)
					get_state(tbuf).prev_lines = vim.api.nvim_buf_get_lines(tbuf, 0, -1, false)
				end,
			})

			vim.api.nvim_create_autocmd("CursorMoved", {
				buffer = args.buf,
				callback = function()
					local tbuf = get_target_buf()
					if not tbuf then
						return
					end

					debounce(tbuf, function()
						local s = get_state(tbuf)
						local new_lines = vim.api.nvim_buf_get_lines(tbuf, 0, -1, false)

						if s.prev_lines then
							highlight_ranges(tbuf, diff_snapshots(s.prev_lines, new_lines))
						end

						s.prev_lines = new_lines
					end, 40)
				end,
			})
		end,
	})
end

return M
