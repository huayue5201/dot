-- json_store/data/anchor.lua
local M = {}

local function sha256(str)
	return vim.fn.sha256(str)
end

-- 获取buffer行（支持缓存）
function M.get_buf_lines(bufnr, use_cache)
	if use_cache then
		return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	end
	-- 如果没有缓存参数，默认不使用缓存
	return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

-- 生成锚点
function M.create_anchor(bufnr, line)
	local lines = M.get_buf_lines(bufnr, true)
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

-- 文本相似度计算（优化版）
local function similarity(a, b)
	if a == b then
		return 1.0
	end
	if #a == 0 or #b == 0 then
		return 0
	end

	-- 快速检查：如果长度差太大，直接返回0
	if math.abs(#a - #b) > 100 then
		return 0
	end

	local min_len = math.min(#a, #b)
	local max_len = math.max(#a, #b)

	-- 如果长度差超过30%，直接返回0
	if (max_len - min_len) / max_len > 0.3 then
		return 0
	end

	local same = 0
	-- 只比较前100个字符（足够判断相似性）
	local limit = math.min(min_len, 100)
	for i = 1, limit do
		if a:sub(i, i) == b:sub(i, i) then
			same = same + 1
		end
	end

	return same / limit
end

-- 计算anchor匹配分数（优化版）
local function score_anchor(anchor_obj, lines, idx)
	if idx < 1 or idx > #lines then
		return 0
	end

	local score = 0

	-- 主文本匹配（权重最高）
	local main_similarity = similarity(anchor_obj.text, lines[idx])
	score = score + main_similarity * 3

	-- hash完全匹配（强匹配）
	if sha256(lines[idx]) == anchor_obj.hash then
		score = score + 5
	end

	-- 上下文匹配（只在前100个字符内比较）
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

-- 在buffer中寻找最佳匹配行（优化版）
function M.find_best_match(bufnr, anchor_obj)
	local lines = M.get_buf_lines(bufnr, true)
	return M.find_best_match_with_cache(bufnr, anchor_obj, lines)
end

-- 使用缓存的lines进行匹配
function M.find_best_match_with_cache(bufnr, anchor_obj, lines_cache)
	local lines = lines_cache or M.get_buf_lines(bufnr, true)

	if #lines == 0 then
		return nil
	end

	local best_score = 0
	local best_line = nil

	-- 限制搜索范围：只在锚点附近搜索
	local search_start = math.max(1, (best_line or 1) - 50)
	local search_end = math.min(#lines, search_start + 100)

	for i = search_start, search_end do
		local s = score_anchor(anchor_obj, lines, i)
		if s > best_score then
			best_score = s
			best_line = i
		end
	end

	-- 阈值：必须达到一定分数才认为有效
	if best_score < 2.0 then
		return nil
	end

	return best_line
end

return M
