-- ============================================================================
-- FIX:(spellwand.nvim: 多行 @spell 节点列号越界)
-- ============================================================================
-- 这是一个「临时修复」，不是插件功能。上游修好后整份删掉即可（含
-- lua/plugins/spellwand.lua 里带 FIX 标记的一行 require/install 调用）。
--
-- 问题（上游 lua/spellwand/spelling.lua:60-72）：
--   vim.spell.check(text) 返回的第三个值是**在 text 内的字节偏移**，而 text 是
--   treesitter @spell 节点（markdown 段落、块注释）的完整文本，可能跨多行。
--   上游直接 `abs_col = start_col + col_offset` 当成单行偏移，行号永远是节点首行。
--   于是第一行之后的行首词会得到远超该行长度的 abs_col，紧接着
--   `vim.str_utfindex(line_text, "utf-16", abs_col)` → E5108 "index out of range"。
--   （复现：markdown 里一个跨两行的段落，第二行有错词。）
--
-- 修法：替换 M.get_spelling_errors，把偏移按 "\n" 拆成 (行, 列) 再算 utf-16 列；
-- treesitter 不可用 / 没有 @spell 时仍回落到上游的逐行扫描（那条路径没有此问题）。
--
-- 清理方式（上游修复后）：删掉本文件 + 插件配置里的 require，并把 install 调用去掉。

local M = {}

-- 守卫元数据：见 lua/fix/init.lua 顶部说明；:FixStatus 查看状态
M.meta = {
	id = "spellwand-multiline-spell",
	title = "多行 @spell 节点的列号越界（abs_col 没按 \\n 拆成行/列）",
	plugin = "spellwand.nvim",
	baseline_rev = "608a3b4",
	-- 上游把「节点内字节偏移」直接加到首行列号上；这行还在 = bug 还在
	buggy = {
		{ file = "lua/spellwand/spelling.lua", contains = "local abs_col = start_col + col_offset" },
	},
	cleanup = { "同时删掉 plugins/spellwand.lua 里带 FIX 标记的 require/install 那一行" },
}

local ERROR_TYPES = {
	bad = "SpellBad",
	cap = "SpellCap",
	["local"] = "SpellLocal",
	rare = "SpellRare",
}

--- 把「节点内字节偏移」换算成 (行, 列)，两者都是 0-based
---@param text string 节点文本（可能含 \n）
---@param offset integer 0-based 字节偏移
---@param start_row integer 节点起始行（0-based）
---@param start_col integer 节点起始列（0-based，字节）
local function resolve_pos(text, offset, start_row, start_col)
	local before = text:sub(1, offset)
	local _, newlines = before:gsub("\n", "")
	if newlines == 0 then
		return start_row, start_col + offset
	end
	local last_nl = before:match(".*()\n") -- 最后一个换行的字节位置
	return start_row + newlines, offset - last_nl
end

--- 修正版的 treesitter 扫描；返回 nil 表示这个策略不适用（交给上游/全量扫描）
local function treesitter_errors(bufnr, opts)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok or not parser then
		return nil
	end
	local parsed, trees = pcall(parser.parse, parser)
	if not parsed or not trees or #trees == 0 then
		return nil
	end
	local got_query, query = pcall(vim.treesitter.query.get, parser:lang(), "highlights")
	if not got_query or not query then
		return nil
	end
	local has_spell_capture = false
	for _, name in ipairs(query.captures) do
		if name == "spell" then
			has_spell_capture = true
			break
		end
	end
	if not has_spell_capture then
		return nil
	end

	local max_errors = opts.max_errors or 999
	local errors, seen, line_cache = {}, {}, {}

	local function line_text(row)
		local cached = line_cache[row]
		if cached == nil then
			cached = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
			line_cache[row] = cached
		end
		return cached
	end

	for _, tree in ipairs(trees) do
		for id, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
			if query.captures[id] == "spell" then
				local text = vim.treesitter.get_node_text(node, bufnr)
				local start_row, start_col = node:range()
				if text and text ~= "" then
					for _, err in ipairs(vim.spell.check(text)) do
						local word, code, offset = err[1], err[2], err[3]
						local row, col = resolve_pos(text, offset, start_row, start_col)
						local key = row .. ":" .. col .. ":" .. word
						if not seen[key] then
							seen[key] = true
							local line = line_text(row)
							-- 越界兜底：宁可列号夹到行尾，也不要让 str_utfindex 报错
							local byte_col = math.min(col, #line)
							local utf16_col = (vim.str_utfindex(line, "utf-16", byte_col) or byte_col) - 1
							errors[#errors + 1] = {
								word = word,
								lnum = row + 1,
								col = col,
								utf16_col = utf16_col,
								utf16_len = vim.str_utfindex(word, "utf-16") or #word,
								type = ERROR_TYPES[code] or ("Spell" .. code:gsub("^%l", string.upper)),
							}
							if #errors >= max_errors then
								return errors
							end
						end
					end
				end
			end
		end
	end
	return errors
end

function M.install()
	local ok, spelling = pcall(require, "spellwand.spelling")
	if not ok or type(spelling.get_spelling_errors) ~= "function" or spelling.__lnum_fix then
		return
	end
	spelling.__lnum_fix = true
	local upstream = spelling.get_spelling_errors

	spelling.get_spelling_errors = function(bufnr, opts)
		opts = opts or {}
		local strategies = opts.strategies or { "full" }
		if type(strategies) == "function" then
			strategies = strategies(bufnr)
		end
		for _, name in ipairs(strategies) do
			if name == "treesitter" then
				local got, result
				vim.api.nvim_buf_call(bufnr, function()
					got, result = pcall(treesitter_errors, bufnr, opts)
				end)
				if got and result then
					return result
				end
			elseif name == "full" then
				-- 上游的逐行扫描本身没问题（列号是行内偏移），直接复用
				return upstream(bufnr, vim.tbl_extend("force", {}, opts, { strategies = { "full" } }))
			end
		end
		return {}
	end
end

return M
