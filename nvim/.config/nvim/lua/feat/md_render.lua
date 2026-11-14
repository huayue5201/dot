-- lua/feat/md_render.lua
---@brief 把 markdown 源码渲染成"给人看"的纯文本行。
---
--- 只做内存里的行变换：不写回 buffer、不落 undo、不加 extmark，因此对
--- buftype=nofile / nomodifiable 的浮窗（LSP hover、各种 readonly 面板）同样可用。
--- 表格对齐复用 feat.table_align 的纯函数，保证"渲染"与"写回"两条路径列宽规则一致。
---
--- 刻意不处理的部分（写清理由，免得以后当成漏掉的功能再补一遍）：
--- * 代码围栏原样保留：渲染结果仍然走 markdown 语法高亮，去掉 ``` 会让围栏里的
---   SQL/Lua 立刻失去高亮（解析器不再把它们当 code block）。
--- * 链接/图片不改写成别的形态，`[text](url)` 在终端里最能表达原意。
--- * 有序列表保留数字，`1.` 本身就是信息。
--- * 表格渲染前先剥掉单元格里的强调标记（`**a**` → `a`），否则列宽按源文本算、
---   显示出来又是错位的；`|` 在行内代码里不算列分隔（`_parse_row` 已处理）。
--- * 表头可以没有前导竖线（`a | b` + `---|---`），缩进和 `>` 引用前缀渲染后放回原处。
--- * setext 标题（`Title` + `=====`/`---`）按标题渲染，下划线行留空行以保持行数不变。
---   文档开头的 YAML frontmatter 原样保留（里面的 `key: value` 不是 setext 标题）。
---
--- 用法：
---   local md_render = require("feat.md_render")
---   local lines = md_render.render_lines(src_lines)

local api = vim.api

local M = {}

---行内 HTML 实体表（sqls 之类用 &nbsp; 做列间距，不解码的话列宽全是假的）
local entities = {
	nbsp = " ",
	amp = "&",
	lt = "<",
	gt = ">",
	quot = '"',
	apos = "'",
	mdash = "—",
	ndash = "–",
	hellip = "…",
	middot = "·",
	times = "×",
	divide = "÷",
	plusmn = "±",
	le = "≤",
	ge = "≥",
	ne = "≠",
	deg = "°",
	micro = "µ",
	copy = "©",
	reg = "®",
	trade = "™",
	larr = "←",
	rarr = "→",
	uarr = "↑",
	darr = "↓",
	bull = "•",
	check = "✓",
	cross = "✗",
	laquo = "«",
	raquo = "»",
}

---标题每级的前缀竖条（纯文本没法加粗，用竖条的粗细表达层级）
local heading_marks = { "█ ", "▊ ", "▋ ", "▌ ", "▍ ", "▎ " }

---任务列表的未完成/完成框
local task_marks = { "☐ ", "☑ " }

local defaults = {
	-- 水平分隔线（`---`）渲染成多长
	hr_width = 40,
	-- 只对齐表格：其余行原样透传（markdown 高亮留给浮窗自己渲染），
	-- 用于「原生外观 + 表格整齐」的混合模式
	tables_only = false,
	-- 表格单元格里的行内代码去掉反引号：conceallevel=2 会把反引号藏掉，
	-- 按字符宽度补的空格会多出来，列看起来就偏了
	strip_code = false,
}

---@param line string
---@return string
local function decode_entities(line)
	if not line:find("&", 1, true) then
		return line
	end
	return (
		line:gsub("&(#?%w+);", function(body)
			local named = entities[body]
			if named then
				return named
			end
			local num = body:match("^#(%d+)$") or body:match("^#[xX](%x+)$")
			if not num then
				return nil -- 原样保留
			end
			local base = body:sub(2, 2):lower() == "x" and 16 or 10
			local ok, char = pcall(vim.fn.nr2char, tonumber(num, base))
			return ok and char or nil
		end)
	)
end

---反引号行内代码段的结束位置（未闭合返回 nil）
---@param line string
---@param i integer
---@return integer?
local function code_span_close(line, i)
	local run = line:match("^`+", i)
	if not run then
		return nil
	end
	local n, from = #run, i + #run
	while true do
		local s, e = line:find("`+", from)
		if not s then
			return nil
		end
		if e - s + 1 == n then
			return e
		end
		from = e + 1
	end
end

---一行里是否有列分隔竖线（转义的和行内代码里的不算）
---@param line string
---@return boolean
local function has_pipe(line)
	local i, n = 1, #line
	while i <= n do
		local c = line:sub(i, i)
		if c == "\\" then
			i = i + 2
		elseif c == "`" then
			local close = code_span_close(line, i)
			i = close and (close + 1) or (i + #(line:match("^`+", i) or "`"))
		elseif c == "|" then
			return true
		else
			i = i + 1
		end
	end
	return false
end

---@param line string
---@return boolean
local function is_table_row(line)
	return has_pipe(line)
end

---@param line string
---@return boolean
local function is_delimiter_row(line)
	-- 前导竖线可以省（GFM 允许 `a | b`），所以不看行首，只看拆出来是不是全是 `---`
	if not has_pipe(line) then
		return false
	end
	local parse_row = require("feat.table_align")._parse_row
	local ok, cells = pcall(parse_row, line)
	if not ok or #cells == 0 then
		return false
	end
	for _, cell in ipairs(cells) do
		if not cell.text:match("^:?-+:?$") then
			return false
		end
	end
	return true
end

---行首的缩进 / 引用前缀（表格可以嵌在 `>` 或缩进里，渲染完要放回去）
---@param line string
---@return string prefix, string core
local function split_prefix(line)
	local prefix = ""
	while true do
		local ws = line:match("^%s*") or ""
		local rest = line:sub(#ws + 1)
		prefix = prefix .. ws
		local after = rest:match("^>%s?") or rest:match("^>")
		if not after then
			return prefix, rest
		end
		prefix = prefix .. after
		line = rest:sub(#after + 1)
	end
end

---setext 标题（`Title` 下一行是全 `=` 或全 `-`）
---@param text string
---@param underline string
---@return boolean
local function is_setext(text, underline)
	local marks = underline:match("^%s*(=+)%s*$") or underline:match("^%s*(-+)%s*$")
	if not marks or #marks < 2 then
		return false
	end
	if text:find("%S") == nil then
		return false
	end
	-- 只接受普通文本行：标题/列表/引用/表格/分隔线本身不参与
	local _, core = split_prefix(text)
	if core == "" or text:match("^%s*>") or core:match("^%s*#") then
		return false
	end
	if core:match("^%s*[-*+%s]%s+") or core:match("%|") or core:match("^%s*[-*_%s]+$") then
		return false
	end
	if core:match("^%s*%d+[.)]%s+") then
		return false
	end
	return true
end

---去掉强调标记：`**a**` / `__a__` / `*a*` / `_a_` → `a`
---反引号代码段原样保留；`_` 只在词边界外生效（`foo_bar_baz` 不动）。
---@param line string
---@return string
local function strip_emphasis(line)
	if not line:find("[*_]") then
		return line
	end
	local function plain(text)
		text = text:gsub("%*%*(.-)%*%*", "%1")
		text = text:gsub("__(.-)__", "%1")
		-- 单字符强调：要求标记两侧都是非词字符（`2*3*4`、`foo_bar_baz` 不动）。
		-- Lua 没有“或”与零宽断言，所以头尾各补一个空格当哨兵。
		text = " " .. text .. " "
		text = text:gsub("([^%w*])%*([^%s*][^*]-)%*([^%w*])", "%1%2%3")
		text = text:gsub("([^%w_])_([^%s_][^_]-)_([^%w_])", "%1%2%3")
		return text:sub(2, -2)
	end

	local out, i, n = {}, 1, #line
	while i <= n do
		local tick = line:find("`", i, true)
		if not tick then
			out[#out + 1] = plain(line:sub(i))
			break
		end
		local close = code_span_close(line, tick)
		if not close then
			out[#out + 1] = plain(line:sub(i)) -- 未闭合的 ` 当普通文本
			break
		end
		if tick > i then
			out[#out + 1] = plain(line:sub(i, tick - 1))
		end
		out[#out + 1] = line:sub(tick, close)
		i = close + 1
	end
	return table.concat(out)
end

---@param line string
---@param opts table
---@return string
local function inline(line, opts)
	-- 行内强调标记（反引号保留，它是"这是代码"的提示）
	line = strip_emphasis(line)

	-- 水平分隔线（先于列表判断，`- - -` 也归这里）
	local rule = line:match("^%s*([-*_])%s*$") ~= nil
	if not rule and line:match("^%s*[-*_]%s*[-*_%s]*$") then
		local dashes = select(2, line:gsub("[-*_]", ""))
		local spaces = select(2, line:gsub("%s", ""))
		rule = dashes >= 3 and dashes + spaces == #line
	end
	if rule then
		return string.rep("─", opts.hr_width)
	end

	-- 标题：`## foo` → `▋ foo`
	local hashes, text = line:match("^(#+)%s+(.*)$")
	if hashes then
		return (heading_marks[#hashes] or "▎ ") .. text
	end

	-- 引用：`> foo` → `▏ foo`（嵌套按层加宽）
	local indent = line:match("^(%s*)") or ""
	local depth, rest = 0, line:sub(#indent + 1)
	while true do
		local after = rest:match("^>%s?(.*)$")
		if not after then
			break
		end
		depth, rest = depth + 1, after
	end
	if depth > 0 then
		return indent .. string.rep("▏ ", depth) .. rest
	end

	-- 任务列表：`- [ ] foo` → `☐ foo`
	local lead, box, rest = line:match("^(%s*)[-*+]%s+%[([ xX])%]%s+(.*)$")
	if box then
		local done = box ~= " "
		return lead .. task_marks[done and 2 or 1] .. rest
	end

	-- 无序列表：`- foo` → `• foo`
	local bullet_indent, bullet = line:match("^(%s*)[-*+]%s+(.*)$")
	if bullet then
		return bullet_indent .. "• " .. bullet
	end

	return line
end

---把一段表格源码行渲染成对齐的纯文本行
---@param lines string[] 已经去掉缩进/引用前缀、已剥强调
---@return string[]|nil
local function render_table(lines)
	local align = require("feat.table_align")._align_table_lines
	local ok, out = pcall(align, lines)
	if not ok or type(out) ~= "table" or #out ~= #lines then
		return nil
	end
	-- 分隔行换成实线，表格骨架才看得出来（该行只有空格/竖线/冒号/连字符；
	-- 冒号是对齐标记，渲染后已经没有意义，一起换成实线）
	for i, line in ipairs(out) do
		if i == 2 then
			out[i] = (line:gsub("[%-:]", "─"))
		end
	end
	return out
end

---表格单元格里的行内代码去掉反引号（保留内容）
---@param line string
---@return string
local function strip_code_ticks(line)
	if not line:find("`", 1, true) then
		return line
	end
	return (line:gsub("`([^`]*)`", "%1"))
end

---渲染一段非代码文本
---@param lines string[]
---@param out string[]
---@param opts table
local function render_text(lines, out, opts)
	local i = 1
	while i <= #lines do
		local line = lines[i]
		local _, core = split_prefix(line)
		local next_core = ""
		if i + 1 <= #lines then
			next_core = select(2, split_prefix(lines[i + 1]))
		end
		-- 表头 + 分隔行 → 整个表块（表头可以没有前导竖线）
		if i + 1 <= #lines and has_pipe(core) and is_delimiter_row(next_core) then
			local block, prefix = {}, split_prefix(line)
			local j = i
			while j <= #lines do
				local _, body = split_prefix(lines[j])
				if body:find("%S") == nil or not has_pipe(body) then
					break
				end
				block[#block + 1] = strip_emphasis(decode_entities(body))
				if opts.strip_code then
					block[#block] = strip_code_ticks(block[#block])
				end
				j = j + 1
			end
			local aligned = render_table(block)
			if aligned then
				for _, l in ipairs(aligned) do
					out[#out + 1] = prefix .. l
				end
			else
				for _, l in ipairs(block) do
					out[#out + 1] = prefix .. inline(l, opts)
				end
			end
			i = j
		elseif i + 1 <= #lines and is_setext(lines[i], lines[i + 1]) then
			-- setext 标题 `Title` + `=====`/`---`：行数不变，下划线行渲染成空行
			local level = lines[i + 1]:match("%s*(=+)") and 1 or 2
			out[#out + 1] = (heading_marks[level] or "▎ ") .. inline(decode_entities(core), opts)
			out[#out + 1] = ""
			i = i + 2
		else
			-- tables_only：非表格行原样透传，交给浮窗按 markdown 渲染
			out[#out + 1] = opts.tables_only and line or inline(decode_entities(line), opts)
			i = i + 1
		end
	end
end

---@param line string
---@return string|nil 围栏标记（"```" / "~~~"）
local function fence_mark(line)
	return line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
end

---把 markdown 行渲染成纯文本行（行数不变）
---@param lines string[]
---@param opts? table
---@return string[]
function M.render_lines(lines, opts)
	opts = vim.tbl_extend("force", defaults, opts or {})

	local out = {}
	local i = 1
	-- YAML frontmatter（`---` … `---`）原样保留：里面的 `key: value` 不能当 setext 标题
	if lines[1] and lines[1]:match("^%-%-%-%s*$") then
		for j = 2, #lines do
			if lines[j]:match("^%-%-%-%s*$") or lines[j]:match("^%.%.%.%s*$") then
				for k = 1, j do
					out[#out + 1] = lines[k]
				end
				i = j + 1
				break
			end
		end
	end
	while i <= #lines do
		local mark = fence_mark(lines[i])
		if mark then
			-- 围栏原样保留：去掉它会让围栏内的代码失去 markdown 高亮
			local fence_char = mark:sub(1, 1)
			local fence_len = #mark
			out[#out + 1] = lines[i]
			i = i + 1
			while i <= #lines do
				out[#out + 1] = lines[i]
				local close = lines[i]:match("^%s*(" .. fence_char:rep(3) .. fence_char .. "*)%s*$")
				i = i + 1
				if close and #close >= fence_len then
					break
				end
			end
		else
			-- 收集到下一个围栏为止的非代码段，交给 render_text 处理
			local seg = {}
			while i <= #lines and not fence_mark(lines[i]) do
				seg[#seg + 1] = lines[i]
				i = i + 1
			end
			render_text(seg, out, opts)
		end
	end

	return out
end

return M
