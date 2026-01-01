-- json_store/data/anchor.lua
local M = {}

local function sha256(str)
	return vim.fn.sha256(str)
end

function M.get_buf_lines(bufnr)
	return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

function M.create_anchor(bufnr, line)
	local lines = M.get_buf_lines(bufnr)
	local text = lines[line] or ""

	return {
		text = text,
		hash = sha256(text),
		before = {
			lines[line - 1] or "",
			lines[line - 2] or "",
		},
		after = {
			lines[line + 1] or "",
			lines[line + 2] or "",
		},
	}
end

local function similarity(a, b)
	if a == b then
		return 1.0
	end
	if #a == 0 or #b == 0 then
		return 0
	end

	if math.abs(#a - #b) > 100 then
		return 0
	end

	local min_len = math.min(#a, #b)
	local max_len = math.max(#a, #b)

	if (max_len - min_len) / max_len > 0.3 then
		return 0
	end

	local same = 0
	local limit = math.min(min_len, 100)
	for i = 1, limit do
		if a:sub(i, i) == b:sub(i, i) then
			same = same + 1
		end
	end

	return same / limit
end

local function score_anchor(anchor_obj, lines, idx)
	if idx < 1 or idx > #lines then
		return 0
	end

	local score = 0

	local main_similarity = similarity(anchor_obj.text, lines[idx])
	score = score + main_similarity * 3

	if sha256(lines[idx]) == anchor_obj.hash then
		score = score + 5
	end

	if idx > 1 then
		score = score + similarity(anchor_obj.before[1], lines[idx - 1]) * 1.5
	end
	if idx > 2 then
		score = score + similarity(anchor_obj.before[2], lines[idx - 2]) * 1.0
	end
	if idx < #lines then
		score = score + similarity(anchor_obj.after[1], lines[idx + 1]) * 1.5
	end
	if idx < #lines - 1 then
		score = score + similarity(anchor_obj.after[2], lines[idx + 2]) * 1.0
	end

	return score
end

function M.find_best_match(bufnr, anchor_obj)
	local lines = M.get_buf_lines(bufnr)
	if #lines == 0 then
		return nil
	end

	local best_score = 0
	local best_line = nil

	local search_start = 1
	local search_end = #lines

	for i = search_start, search_end do
		local s = score_anchor(anchor_obj, lines, i)
		if s > best_score then
			best_score = s
			best_line = i
		end
	end

	if best_score < 2.0 then
		return nil
	end

	return best_line
end

return M
