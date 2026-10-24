-- 轻量「选区文本对比」：只做「快速看差异」这一件事，无第三方依赖。
--
-- 文件级 / 全文件 diff 用 codediff.nvim（lua/plugins/codediff.lua）；本模块只处理
-- 一小段文本的去向：
--   :'<,'>Diff            选区 vs 默认寄存器（respects 'clipboard'）→ 居中浮窗 unified
--   :'<,'>Diff @r         选区 vs 寄存器 r
--   :'<,'>Diff 路径       选区 vs 文件内容
--   :'<,'>Diff !命令      选区 vs 命令输出（shell 输出按行读，失败会报错）
--   :'<,'>Diff!           同样输入的差异 → 临时 tab 双栏（原生 diffthis，可折叠/scrollbind）
-- 窗口内 q / <Esc> 关闭，浮窗模式下 buffer 一并 wipe。
--
-- 实现要点：
--   * diff 全部交给 vim.diff（histogram + linematch + indent_heuristic），本地不写算法。
--   * 行内字符级高亮：linematch 切出的 hunk 里成对的行用「公共前缀/后缀」求出差异区间，
--     用 extmark 贴 TextDiffSpan。时间戳这类「整行只差几位」的场景一眼可见。
--   * 浮窗天然被 tab_workspace 排除在归属之外（core/tab_workspace/util.lua:is_float_win），
--     双栏模式用 nofile scratch buffer（buflisted=false / bufhidden=wipe），不会漏进 bufferline。
--   * 差异行数超过上限时跳过行内高亮，只保留整行底色，避免大段差异卡顿。

local M = {}

local ns = vim.api.nvim_create_namespace("textdiff")

-- 行内差异区间：链接已存在的 DiffText，自定义主题时无需额外配色
vim.api.nvim_set_hl(0, "TextDiffSpan", { link = "DiffText", default = true })

-- 超过这么多行的 hunk 不做字符级拆分（大段差异贴 extmark 太多，收益也低）
local SPAN_MAX_LINES = 300

local DIFF_OPTS = {
	algorithm = "histogram",
	indent_heuristic = true,
	linematch = true,
	-- 数据库/日志导出常见噪音：行尾空格差异、CRLF 差异直接忽略
	ignore_whitespace_change_at_eol = true,
	ignore_cr_at_eol = true,
}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Diff" })
end

---@param reg string
---@return string[]?
local function reg_lines(reg)
	local ok, info = pcall(vim.fn.getreginfo, reg)
	if not ok or type(info) ~= "table" then
		return nil
	end
	local lines = info.regcontents
	if not lines or (#lines == 1 and lines[1] == "") then
		return nil
	end
	return lines
end

---'clipboard' 含 unnamedplus 时默认寄存器取 "+"，与 y 的行为保持一致
---@return string
local function default_reg()
	local cb = vim.o.clipboard
	if cb:find("unnamedplus", 1, true) then
		return "+"
	elseif cb:find("unnamed", 1, true) then
		return "*"
	end
	return '"'
end

---解析命令参数为「行数组 + 展示用标签」
---@param arg string?
---@return string[]? lines
---@return string? label
---@return string? err
local function target_lines(arg)
	if arg == nil or arg == "" then
		local reg = default_reg()
		local lines = reg_lines(reg)
		if not lines then
			return nil, nil, "默认寄存器为空（先 y 一段，或 :Diff @r / :Diff 文件）"
		end
		return lines, "寄存器 @" .. reg
	end

	local first = arg:sub(1, 1)

	if first == "@" then
		local reg = arg:sub(2)
		if reg == "" then
			reg = default_reg()
		end
		local lines = reg_lines(reg)
		if not lines then
			return nil, nil, "寄存器 @" .. reg .. " 为空"
		end
		return lines, "寄存器 @" .. reg
	end

	if first == "!" then
		local cmd = arg:sub(2)
		local out = vim.fn.systemlist(cmd)
		if vim.v.shell_error ~= 0 then
			return nil, nil, ("命令失败（%d）: %s"):format(vim.v.shell_error, cmd)
		end
		if #out == 0 then
			return nil, nil, "命令无输出: " .. cmd
		end
		return out, "$ " .. cmd
	end

	local path = vim.fn.expand(arg)
	if vim.fn.filereadable(path) ~= 1 then
		return nil, nil, "文件不可读: " .. path
	end
	local lines = vim.fn.readfile(path)
	if vim.fn.getline(1) == "" and #lines == 0 then
		return nil, nil, "文件为空: " .. path
	end
	return lines, vim.fn.fnamemodify(path, ":~:.")
end

---成对行的行内差异区间（按字节列返回 0-based 半开区间）
---@return integer? as, integer? ae, integer? bs, integer? be
local function span(a, b)
	local la, lb = #a, #b
	local n = math.min(la, lb)
	local p = 0
	while p < n and a:byte(p + 1) == b:byte(p + 1) do
		p = p + 1
	end
	local s = 0
	while s < n - p and a:byte(la - s) == b:byte(lb - s) do
		s = s + 1
	end
	return p, la - s, p, lb - s
end

---给一对行贴行内差异高亮
local function mark_pair(buf1, l1, line1, buf2, l2, line2)
	local as, ae, bs, be = span(line1, line2)
	if as >= ae or bs >= be then
		return
	end
	pcall(vim.api.nvim_buf_set_extmark, buf1, ns, l1, as, { end_col = ae, hl_group = "TextDiffSpan" })
	pcall(vim.api.nvim_buf_set_extmark, buf2, ns, l2, bs, { end_col = be, hl_group = "TextDiffSpan" })
end

----------------------------------------------------------------------
-- 浮窗 unified
----------------------------------------------------------------------

---把 unified 文本里的 -/+ 行按顺序配对，贴行内高亮
---@param buf integer
---@param lines string[]
local function mark_unified(buf, lines)
	local removed, added = {}, {}

	local function flush()
		for i = 1, math.min(#removed, #added) do
			local a, b = removed[i], added[i]
			local as, ae, bs, be = span(a.text, b.text)
			if as < ae and bs < be then
				pcall(vim.api.nvim_buf_set_extmark, buf, ns, a.row, as + 1, {
					end_col = ae + 1,
					hl_group = "TextDiffSpan",
				})
				pcall(vim.api.nvim_buf_set_extmark, buf, ns, b.row, bs + 1, {
					end_col = be + 1,
					hl_group = "TextDiffSpan",
				})
			end
		end
		removed, added = {}, {}
	end

	for i, line in ipairs(lines) do
		local head = line:sub(1, 1)
		if head == "-" and line:sub(1, 3) ~= "---" then
			removed[#removed + 1] = { row = i - 1, text = line:sub(2) }
		elseif head == "+" and line:sub(1, 3) ~= "+++" then
			added[#added + 1] = { row = i - 1, text = line:sub(2) }
		else
			flush()
		end
	end
	flush()
end

---@param lines string[]
---@param title string
local function open_float(lines, title)
	local ui_w = vim.o.columns
	local ui_h = vim.o.lines - vim.o.cmdheight
	local chrome = vim.o.laststatus == 0 and 0 or 1

	local text_w = 0
	for i = 1, math.min(#lines, 500) do
		text_w = math.max(text_w, vim.fn.strdisplaywidth(lines[i]))
	end

	local width = math.min(math.floor(ui_w * 0.9), math.max(40, text_w + 4))
	local height = math.min(math.floor(ui_h * 0.75), math.max(4, #lines))
	width = math.max(20, math.min(width, ui_w - 6))
	height = math.max(3, math.min(height, ui_h - chrome - 4))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "diff"
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = math.max(0, math.floor((ui_h - height) / 2) - 1),
		col = math.max(0, math.floor((ui_w - width) / 2)),
		title = " " .. title .. " ",
		title_pos = "center",
		noautocmd = true,
	})

	vim.wo[win].wrap = false
	vim.wo[win].foldenable = false
	vim.wo[win].spell = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	for _, lhs in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", lhs, close, { buffer = buf, nowait = true, desc = "Diff: 关闭" })
	end

	mark_unified(buf, lines)
end

----------------------------------------------------------------------
-- 临时 tab 双栏
----------------------------------------------------------------------

---@param a string[]
---@param b string[]
---@param label_a string
---@param label_b string
local function open_tab(a, b, label_a, label_b)
	local hunks = vim.diff(table.concat(a, "\n") .. "\n", table.concat(b, "\n") .. "\n", vim.tbl_extend("force", DIFF_OPTS, {
		result_type = "indices",
		ctxlen = 3,
	}))

	local ok_tab, tab = pcall(vim.cmd.tabnew)
	if not ok_tab then
		return
	end

	local bufs, wins = {}, {}
	local sides = {
		{ a, label_a, "Diff (选区)" },
		{ b, label_b, "Diff (" .. label_b .. ")" },
	}
	for i, side in ipairs(sides) do
		local buf
		if i == 1 then
			buf = vim.api.nvim_get_current_buf()
		else
			-- vnew（而不是 vsplit）：vsplit 会让两个窗口共用同一个 buffer，
			-- 第二次 set_lines 会撞上刚设好的 nomodifiable
			vim.cmd("vnew")
			buf = vim.api.nvim_get_current_buf()
		end
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].swapfile = false
		vim.bo[buf].buflisted = false
		vim.bo[buf].undolevels = -1
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, side[1])
		vim.bo[buf].filetype = "diff"
		vim.bo[buf].modifiable = false
		vim.bo[buf].modified = false
		bufs[i], wins[i] = buf, vim.api.nvim_get_current_win()
		vim.cmd("diffthis")
	end

	local function close()
		for i = 1, 2 do
			local w = wins[i]
			if w and vim.api.nvim_win_is_valid(w) then
				pcall(vim.api.nvim_win_close, w, true)
			end
		end
		for i = 1, 2 do
			local buf = bufs[i]
			if buf and vim.api.nvim_buf_is_valid(buf) then
				pcall(vim.api.nvim_buf_delete, buf, { force = true })
			end
		end
		if #vim.api.nvim_list_tabpages() > 1 then
			pcall(vim.cmd.tabclose)
		end
	end

	for i = 1, 2 do
		for _, lhs in ipairs({ "q", "<Esc>" }) do
			vim.keymap.set("n", lhs, close, { buffer = bufs[i], nowait = true, desc = "Diff: 关闭" })
		end
	end

	if #hunks > 0 then
		local first = hunks[1]
		if first[1] > 0 and first[1] <= #a then
			pcall(vim.api.nvim_win_set_cursor, wins[1], { first[1], 0 })
		end
		if first[3] > 0 and first[3] <= #b then
			pcall(vim.api.nvim_win_set_cursor, wins[2], { first[3], 0 })
		end
	end

	local total = 0
	for _, h in ipairs(hunks) do
		local _, ca, sb, cb = h[1], h[2], h[3], h[4]
		total = total + ca + cb
	end
	if total > SPAN_MAX_LINES then
		return
	end
	for _, h in ipairs(hunks) do
		local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
		if ca > 0 and ca == cb and sa > 0 and sb > 0 then
			for k = 0, ca - 1 do
				local la, lb = sa - 1 + k, sb - 1 + k
				if la < #a and lb < #b then
					mark_pair(bufs[1], la, a[la + 1], bufs[2], lb, b[lb + 1])
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- 入口
----------------------------------------------------------------------

---@param args table  user command 参数（.line1/.line2/.args/.bang）
function M.run(args)
	local a = vim.api.nvim_buf_get_lines(0, args.line1 - 1, args.line2, true)
	if #a == 0 then
		notify("选区为空", vim.log.levels.WARN)
		return
	end

	local b, label, err = target_lines(args.args)
	if not b then
		notify(err or "无法取得对比内容", vim.log.levels.ERROR)
		return
	end

	local text_a = table.concat(a, "\n")
	local text_b = table.concat(b, "\n")
	if text_a == text_b then
		notify("两侧内容完全相同")
		return
	end

	local opts = vim.tbl_extend("force", DIFF_OPTS, { result_type = "unified", ctxlen = 3, interhunkctxlen = 3 })
	local unified = vim.diff(text_a .. "\n", text_b .. "\n", opts)
	if not unified or unified == "" then
		notify("两侧内容完全相同（仅空白差异被忽略）")
		return
	end

	local lines = vim.split(unified, "\n", { plain = true })
	-- vim.split 末尾留空串，去掉
	while #lines > 0 and lines[#lines] == "" do
		table.remove(lines)
	end

	if args.bang then
		open_tab(a, b, "选区", label or "对比")
	else
		open_float(lines, ("Diff  %s  ⇄  选区"):format(label or "对比"))
	end
end

function M.setup()
	vim.api.nvim_create_user_command("Diff", function(cmd)
		M.run({ line1 = cmd.line1, line2 = cmd.line2, args = cmd.args, bang = cmd.bang })
	end, {
		range = "%",
		bang = true,
		nargs = "?",
		complete = "file",
		desc = "对比选区与寄存器/文件/命令输出（! = 双栏临时 tab）",
	})

	local function visual(command)
		return function()
			if vim.fn.mode() ~= "V" then
				return "D"
			end
			return command .. "<CR>"
		end
	end

	vim.keymap.set("x", "D", visual(":Diff"), { expr = true, desc = "Diff: 选区对比寄存器（浮窗）" })
	vim.keymap.set("x", "gD", visual(":Diff!"), { expr = true, desc = "Diff: 选区对比寄存器（双栏 tab）" })
end

return M
