-- 用户视角：lib/menu（接管 vim.ui.select 的浮窗菜单）。
--
--   nvim --headless -u NONE -l tests/menu.lua
--
-- 覆盖：
--   1. 过滤：空查询返回全部、模糊命中带高亮位置、无命中为空
--   2. 标签：所有行连续编号、右对齐到同一列
--   3. 数字键直接选中、<C-n> 移动 + <CR> 选中
--   4. 输入字符过滤、<BS> 退格、<C-u> 清空
--   5. Esc 取消 → 回调 (nil, nil)
--   6. 单飞：菜单开着时第二次调用只返回 false，不叠第二层；结束后能再开
--   6c. 输入模式下 Esc 只退回导航模式，不关菜单；再按 Esc 才取消
--   6d. ? 打开按键帮助浮窗，任意键收起
--   8. 大写查询走大小写不敏感的兜底，命中位置必须 0-based（高亮不偏格）；中文位置正确
--   9. 输入模式的数字是查询字符（不是直接选中）；中文可输入、<BS> 多字节安全
--   10. 列表超过 max_height 时滚动，选中项始终在视口内
--   11. 锚点贴光标所在的屏幕行列（长行折行时不跑到行首），且始终钳制在屏幕内
--   14. 索引模式：<C-g> + 数字 + <CR>（越界不选、<BS>/<C-u> 可编辑、过滤后作用于结果）
--   13. gg 首项 / G 末项（g 后接其它键不作数）
--   12. 每一行都带序号，文本列对齐（第 19 项以后也一样）；输入模式下序号变暗；关菜单后 buffer 全部释放
--   7. setup() 之后 vim.ui.select 走的是这个菜单；M.builtin 保留原实现
--   15. 动画模式：opts.tick 超时推进帧号，format_item(item, frame) 拿到递增帧
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

local menu = require("lib.menu")
local function cp(n)
	io.stderr:write("CP " .. n .. "\n")
end

local fails = {}
local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

local kc = vim.keycode
local function feed(keys)
	vim.api.nvim_feedkeys(keys, "n", false)
end

----------------------------------------------------------------------
-- 1. 过滤
----------------------------------------------------------------------

local items = { "alpha", "beta", "gamma", "delta" }
check(#menu.filter(items, "", tostring) == 4, "空查询应返回全部")
local hits = menu.filter(items, "ga", tostring)
check(#hits == 1 and hits[1].text == "gamma", "查询 ga 应命中 gamma")
check(type(hits[1].positions) == "table" and #hits[1].positions == 2, "命中应带两个高亮位置")
check(#menu.filter(items, "zzz", tostring) == 0, "无命中应为空")

----------------------------------------------------------------------
-- 2. 标签
----------------------------------------------------------------------

check(menu.label(1) == "1" and menu.label(19) == "19", "所有行都带序号（19 以后不会突然没有标签）")
check(menu.label_width(4) == 2 and menu.label_width(140) == 3, "标签列宽：最少 2 位，按总项数增长")
check(menu.line(2, "x", 2) == " 2 x", "行文本 = 右对齐序号 + 空格 + 内容")
check(menu.line(12, "x", 2) == "12 x", "两位数序号占满 2 列时不补空格")

----------------------------------------------------------------------
-- 3/4/5. 键位：数字选中、移动、输入过滤、退格、清空、取消
----------------------------------------------------------------------

local function run(keys, given_items, opts)
	local got = { called = 0 }
	feed(keys)
	menu.select(given_items or items, opts or {}, function(item, idx)
		got.called = got.called + 1
		got.item, got.idx = item, idx
	end)
	return got
end

local r = run("2")
check(r.called == 1 and r.item == "beta", "按 2 应选中 beta，实际 " .. tostring(r.item))

r = run(kc("<C-n>") .. kc("<C-n>") .. kc("<CR>"))
check(r.item == "gamma", "两次 <C-n> 后 <CR> 应选中 gamma，实际 " .. tostring(r.item))

r = run(kc("<C-p>") .. kc("<CR>"))
check(r.item == "delta", "<C-p> 应回绕到末项")

r = run("i" .. "ga" .. kc("<CR>"))
check(r.item == "gamma", "i 进输入模式后输入 ga 应选中 gamma，实际 " .. tostring(r.item))

r = run("f" .. "ga" .. kc("<CR>"))
check(r.item == "gamma", "f 也能进输入模式，实际 " .. tostring(r.item))

r = run("ga" .. kc("<CR>"))
check(r.item == "alpha", "导航模式下字母不进入查询（应选第一项），实际 " .. tostring(r.item))

r = run("jj" .. kc("<CR>"))
check(r.item == "gamma", "导航模式 j 应下移，实际 " .. tostring(r.item))

r = run("ijk" .. kc("<C-u>") .. kc("<CR>"))
check(r.item == "alpha", "输入模式 j/k 是查询字符（<C-u> 清空后应选回第一项）")

r = run("i" .. "gm" .. kc("<BS>") .. "amm" .. kc("<CR>"))
check(r.item == "gamma", "退格后继续输入应仍能命中 gamma，实际 " .. tostring(r.item))

r = run("i" .. "zzz" .. kc("<C-u>") .. kc("<CR>"))
check(r.item == "alpha", "<C-u> 清空查询后 <CR> 应选回第一项")

r = run(kc("<Esc>"))
check(r.called == 1 and r.item == nil, "Esc 应回调 (nil, nil)")

-- M-<pivot> 已移除：M-s 不再选第 11 项，只剩 1-9 与 <C-g> 索引模式
r = run(kc("<M-s>") .. kc("<CR>"), { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l" })
check(r.item == "a", "M-<pivot> 应已失效（停在首项），实际 " .. tostring(r.item))

----------------------------------------------------------------------
-- 5b. 提示文本在边框中间（含输入模式标记）
----------------------------------------------------------------------

local titles, bodies, cursors, marks, inputs = {}, {}, {}, {}, {}
local orig_rk_title = menu._read_key
local title_reads = 0
menu._read_key = function()
	title_reads = title_reads + 1
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(w)
		local parts = {}
		if cfg.title then
			for _, chunk in ipairs(cfg.title) do
				parts[#parts + 1] = chunk[1]
			end
		end
		local text = table.concat(parts)
		local buf = vim.api.nvim_win_get_buf(w)
		local body = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		if cfg.relative ~= "" and body[1] and body[1]:find("❯", 1, true) then
			local hl = {}
			for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
				hl[#hl + 1] = (m[4] or {}).hl_group
			end
			inputs[#inputs + 1] = { line = body[1], cursor = vim.api.nvim_win_get_cursor(w), hl = hl }
		end
		if text == "Pick: " then
			titles[#titles + 1] = { text = text, pos = cfg.title_pos }
			bodies[#bodies + 1] = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false)
			cursors[#cursors + 1] = vim.api.nvim_win_get_cursor(w)
			local hl = {}
			for _, m in
				ipairs(vim.api.nvim_buf_get_extmarks(vim.api.nvim_win_get_buf(w), -1, 0, -1, { details = true }))
			do
				hl[#hl + 1] = (m[4] or {}).hl_group
			end
			marks[#marks + 1] = hl
		end
	end
	if title_reads == 1 then
		return "i"
	elseif title_reads == 2 then
		return "g"
	end
	return nil
end
menu.select({ "alpha", "beta" }, { prompt = "Pick: ", format_item = tostring }, function() end)
menu._read_key = orig_rk_title
check(#titles >= 2, "应在每次读键前都更新边框标题")
check(titles[1] and titles[1].text:find("Pick: ", 1, true) ~= nil, "标题应包含 prompt")
check(titles[1] and titles[1].pos == "center", "标题应居中（title_pos = center）")
-- 输入框是**独立的浮窗**，贴在列表下方；列表本身不再有输入行
local last_body = bodies[#bodies]
check(last_body and last_body[1] ~= nil and not last_body[1]:find("❯", 1, true), "列表里不应再有输入行")
local last_input = inputs[#inputs]
check(last_input ~= nil, "输入模式应有一个独立的输入框浮窗")
check(
	last_input and last_input.line == " ❯ g ",
	"输入框内容应为查询文本，实际 " .. tostring(last_input and last_input.line)
)
check(
	last_input and last_input.cursor[1] == 1 and last_input.cursor[2] == 6,
	"光标应停在输入框查询末尾（1,6），实际 " .. vim.inspect(last_input and last_input.cursor)
)
check(bodies[1] and bodies[1][1] == "  1 alpha", "导航模式下没有查询行")
-- 输入框的光标格要有 Cursor 高亮：浮窗里的真光标未必被终端显示，这一格保证位置可见
local last_marks = (last_input and last_input.hl) or {}
local has_cursor = false
for _, g in ipairs(last_marks) do
	if g == "Cursor" then
		has_cursor = true
	end
end
check(has_cursor, "输入框应有一个 Cursor 高亮的格子标记光标位置")

----------------------------------------------------------------------
-- 6. 单飞
----------------------------------------------------------------------

-- 菜单开着的时候再调一次：立即返回 false，且不会叠第二层
local first = { called = 0 }
local second_result = nil
feed("2")
menu.select({ "one", "two" }, {}, function(item)
	first.called = first.called + 1
	first.item = item
	-- 菜单内部回调时 _busy 已经放开：再开一次应能成功（用 Esc 立刻关掉，避免阻塞）
	feed(kc("<Esc>"))
	second_result = menu.select({ "x" }, {}, function() end)
end)
check(first.called == 1 and first.item == "two", "第一次调用应正常选中")
check(second_result == true, "菜单结束后应能再次打开")

-- 真正在菜单开着时重入：用一次嵌套调用模拟（第二次直接返回 false）
local reentry, reentry_cancelled = nil, false
local started = false
local orig_read_key = menu._read_key
menu._read_key = function()
	if not started then
		started = true
		reentry = menu.select({ "nested" }, { prompt = "nested: " }, function(item)
			reentry_cancelled = item == nil
		end)
	end
	return nil -- 立刻结束当前菜单
end
menu.select({ "outer" }, {}, function() end)
menu._read_key = orig_read_key
check(reentry == false, "菜单开着时重入应返回 false（不叠第二层）")
check(reentry_cancelled, "被拒的请求应收到 nil 回调，调用方不会挂死")
check(menu._busy == false, "菜单结束后 _busy 应复位")

----------------------------------------------------------------------
-- 6b. 浮窗被外部关掉：循环必须立刻结束，不能变成"看不见的菜单"继续吃键
----------------------------------------------------------------------

local ext = { n = 0 }
local orig_read_key_6b = menu._read_key
menu._read_key = function()
	-- 模拟"读键期间浮窗被 :q / 切 tab / 别的插件关掉"，同时手上还有键要继续消费
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(w)
		local text = ""
		if cfg.title then
			for _, chunk in ipairs(cfg.title) do
				text = text .. chunk[1]
			end
		end
		if text:find("External: ", 1, true) then
			vim.api.nvim_win_close(w, true)
		end
	end
	return "1" -- 本来会选中第 1 项，但窗口已经没了
end
menu.select({ "a", "b" }, { prompt = "External: " }, function(item)
	ext.n = ext.n + 1
	ext.item = item
end)
menu._read_key = orig_read_key_6b
-- WinClosed 会往队列里塞一个 Esc 用来解除阻塞；这里是模拟关闭，Esc 没人消费，先冲掉
pcall(vim.fn.feedkeys, "", "x")
check(ext.n == 1, "浮窗被外部关闭后应结束并回调一次，实际回调 " .. ext.n .. " 次")
check(ext.item == nil, "外部关闭应视为取消（回调 nil）")
check(menu._busy == false, "外部关闭后 _busy 应复位")

----------------------------------------------------------------------
-- 6c. Esc 的两段语义：输入模式 -> 导航模式 -> 取消
----------------------------------------------------------------------

-- 第一次 Esc 只退出输入模式（查询保留），第二次 Esc 才取消
r = run("i" .. "ga" .. kc("<Esc>") .. kc("<Esc>"))
check(r.called == 1 and r.item == nil, "输入模式连按两次 Esc 才取消，实际 " .. tostring(r.item))

-- 退出输入模式后查询仍在：Esc 之后按 <CR> 应选中过滤后的第一项（gamma）
r = run("i" .. "ga" .. kc("<Esc>") .. kc("<CR>"))
check(r.item == "gamma", "Esc 退出输入模式应保留查询（gamma），实际 " .. tostring(r.item))

-- 退出输入模式后 j/k 恢复为移动
r = run("i" .. kc("<Esc>") .. "j" .. kc("<CR>"))
check(r.item == "beta", "Esc 之后 j 应恢复为移动，实际 " .. tostring(r.item))

-- 浮窗用 enter=true 才能画真光标，关掉后必须把焦点还给原窗口
local before_win = vim.api.nvim_get_current_win()
r = run("2")
check(vim.api.nvim_get_current_win() == before_win, "关闭菜单后焦点应回到原窗口")

----------------------------------------------------------------------
-- 6d. ? 打开按键帮助浮窗
----------------------------------------------------------------------

local help_wins = {}
local orig_rk_help = menu._read_key
local help_reads = 0
menu._read_key = function()
	help_reads = help_reads + 1
	local found = nil
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(w)
		local text = ""
		if cfg.title then
			for _, chunk in ipairs(cfg.title) do
				text = text .. chunk[1]
			end
		end
		if text == " Help " then
			found = { win = w, lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false) }
		end
	end
	help_wins[help_reads] = found
	if help_reads == 1 then
		return "?"
	elseif help_reads == 2 then
		return "x" -- 任意键只收帮助
	end
	return nil
end
menu.select({ "alpha", "beta" }, { prompt = "Query: ", format_item = tostring }, function() end)
menu._read_key = orig_rk_help
check(help_wins[1] == nil, "按 ? 之前不应有帮助浮窗")
check(help_wins[2] ~= nil, "按 ? 之后应出现帮助浮窗")
local hl = help_wins[2] and table.concat(help_wins[2].lines, "\n") or ""
check(hl:find("<Esc>", 1, true) ~= nil and hl:find("<CR>", 1, true) ~= nil, "帮助应列出按键说明")
check(#vim.api.nvim_list_wins() >= 1, "帮助收起后不应残留窗口")

----------------------------------------------------------------------
-- 8. 大小写 / 多字节：兜底位置也必须跟 matchfuzzypos 一样是 0-based
----------------------------------------------------------------------

-- matchfuzzypos 是大小写敏感的（"FOO" 匹配不到 "foo bar"），所以大写查询走兜底；
-- 兜底曾经把 find 的 1-based 位置塞进 positions，高亮整体偏一格。
local up = menu.filter({ "foo bar" }, "FOO", tostring)
check(#up == 1, "大写查询应命中 foo bar，实际 " .. #up .. " 个")
local up_pos = up[1] and table.concat(up[1].positions or {}, ",") or ""
check(up_pos == "0,1,2", "兜底命中位置应为 0-based 字节偏移 0,1,2，实际 " .. up_pos)

local cjk = menu.filter({ "zhong 中文" }, "中文", tostring)
check(
	#cjk == 1 and cjk[1].positions[1] == 6,
	"中文查询应命中并给出字符起始字节，实际 " .. vim.inspect(cjk[1] and cjk[1].positions)
)
check(
	#(cjk[1] and cjk[1].positions or {}) == 2,
	"中文命中不应把字符拆成字节，实际 " .. vim.inspect(cjk[1] and cjk[1].positions)
)

----------------------------------------------------------------------
-- 9. 输入模式下的数字是查询字符；中文可输入、退格安全
----------------------------------------------------------------------

-- 导航模式按 1 选第 1 项（"b2"）；输入模式按 1 应过滤出 "a1"
r = run("1", { "b2", "a1" })
check(r.item == "b2", "导航模式按 1 应选中第 1 项，实际 " .. tostring(r.item))
r = run("i" .. "1" .. kc("<CR>"), { "b2", "a1" })
check(r.item == "a1", "输入模式按 1 应作为查询过滤而不是选中第 1 项，实际 " .. tostring(r.item))

r = run("i" .. "中" .. kc("<BS>") .. "英" .. kc("<CR>"), { "中文", "英文" })
check(r.item == "英文", "中文输入与 <BS> 退格应可用，实际 " .. tostring(r.item))

----------------------------------------------------------------------
-- 10. 超过 max_height 时滚动，选中项始终可见
----------------------------------------------------------------------

local many = {}
for i = 1, 40 do
	many[i] = ("item%02d"):format(i)
end
local seen = {}
local orig_rk_scroll = menu._read_key
local reads = 0
local old_max = menu.config.max_height
menu.config.max_height = 5
menu._read_key = function()
	reads = reads + 1
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(w)
		local text = ""
		if cfg.title then
			for _, chunk in ipairs(cfg.title) do
				text = text .. chunk[1]
			end
		end
		if text == "Many: " then
			seen[#seen + 1] = {
				height = vim.api.nvim_win_get_height(w),
				lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false),
				cursor = vim.api.nvim_win_get_cursor(w),
			}
		end
	end
	if reads <= 20 then
		return kc("<C-n>")
	end
	return kc("<Esc>")
end
menu.select(many, { prompt = "Many: ", format_item = tostring }, function() end)
menu._read_key = orig_rk_scroll
menu.config.max_height = old_max

local tall = false
for _, s in ipairs(seen) do
	if s.height > 5 then
		tall = true
	end
end
check(#seen > 0, "应能采样到菜单浮窗")
check(not tall, "浮窗高度不应超过 max_height=5")
local last_seen = seen[#seen]
check(
	last_seen and #last_seen.lines == 5,
	"视口应只有 5 行，实际 " .. tostring(last_seen and #last_seen.lines)
)
check(
	last_seen and last_seen.lines[5] and last_seen.lines[5]:find("item21", 1, true) ~= nil,
	"第 21 项应滚入视口底部，实际 " .. tostring(last_seen and last_seen.lines[5])
)
check(
	last_seen and last_seen.cursor[1] == 5,
	"选中项应落在视口最后一行，实际 " .. vim.inspect(last_seen and last_seen.cursor)
)

----------------------------------------------------------------------
-- 11. 锚点用光标所在屏幕行列（长行折行时不能跑到行首）
----------------------------------------------------------------------

local anchor = {}
vim.wo.wrap = true
vim.api.nvim_buf_set_lines(0, 0, -1, false, { string.rep("abcdefghij", 20) })
vim.api.nvim_win_set_cursor(0, { 1, 95 })
vim.cmd("redraw")
-- 期望值用 screenpos 独立算：光标在第 1 个屏幕行的后面几行，行首则在第 1 行
local want = vim.fn.screenpos(0, 1, 96)
local line_start = vim.fn.screenpos(0, 1, 1)
local orig_rk_anchor = menu._read_key
menu._read_key = function()
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(w)
		local text = ""
		if cfg.title then
			for _, chunk in ipairs(cfg.title) do
				text = text .. chunk[1]
			end
		end
		if text == "Anchor: " then
			anchor = vim.tbl_extend("force", anchor, {
				win = w,
				row = cfg.row,
				col = cfg.col,
				width = cfg.width,
			})
		end
	end
	return kc("<Esc>")
end
menu.select({ "a", "b" }, { prompt = "Anchor: " }, function() end)
menu._read_key = orig_rk_anchor

check(anchor.win ~= nil, "应打开菜单浮窗")
check(want.row > line_start.row, "测试预设：光标应在折行后的屏幕行，实际 " .. vim.inspect(want))
check(
	anchor.row == want.row,
	("菜单应贴光标屏幕行 %d，实际 %s（行首在第 %d 行）"):format(
		want.row,
		tostring(anchor.row),
		line_start.row
	)
)
check(anchor.col == want.col, ("菜单应贴光标屏幕列 %d，实际 %s"):format(want.col, tostring(anchor.col)))
-- 宽度是自适应的（config.width 只是上限），比的是浮窗实际宽度
check(
	anchor.col + anchor.width <= vim.go.columns + 1,
	("菜单不应超出右边界（col=%s, width=%d, columns=%d）"):format(
		tostring(anchor.col),
		tostring(anchor.width),
		vim.go.columns
	)
)

----------------------------------------------------------------------
-- 12. 每一行都带序号、文本列对齐；输入模式下序号变暗；关菜单后 buffer 全部释放
----------------------------------------------------------------------

local many3 = {}
for i = 1, 30 do
	many3[i] = ("abc%02d"):format(i)
end
local snap = {}
local old_max3 = menu.config.max_height
menu.config.max_height = 40
-- render 会把视口高度再按屏幕行数收窄（vim.go.lines - 4），headless 默认只有 24 行，
-- 不放大就拿不到第 21 行。测完后恢复。
local old_lines3 = vim.o.lines
vim.o.lines = 44
local orig_rk_label = menu._read_key
local step = 0
menu._read_key = function()
	step = step + 1
	if step == 5 then
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			local cfg = vim.api.nvim_win_get_config(w)
			local text = ""
			if cfg.title then
				for _, chunk in ipairs(cfg.title) do
					text = text .. chunk[1]
				end
			end
			if text == "Lbl: " then
				local buf = vim.api.nvim_win_get_buf(w)
				snap.lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				snap.marks = {}
				snap.label_hl = {}
				for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
					if m[4].hl_group == "lib-menu-match" then
						snap.marks[#snap.marks + 1] = { line = m[2], col = m[3] }
					elseif m[4].hl_group == "lib-menu-label" or m[4].hl_group == "lib-menu-label-dim" then
						snap.label_hl[m[2]] = m[4].hl_group
					end
				end
			end
		end
	end
	local keys = { "i", "a", "b", "c", kc("<Esc>"), kc("<Esc>") }
	return keys[step]
end
local bufs_before = {}
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	bufs_before[b] = true
end
menu.select(many3, { prompt = "Lbl: ", format_item = tostring }, function() end)
menu._read_key = orig_rk_label
menu.config.max_height = old_max3
vim.o.lines = old_lines3

local marks_by_line = {}
for _, m in ipairs(snap.marks or {}) do
	marks_by_line[m.line] = marks_by_line[m.line] or {}
	table.insert(marks_by_line[m.line], m.col)
end
-- 标签列宽 2（30 项），所有行都是 " 数字 文本"：文本从 0-based 列 4 开始，命中在 4,5,6
local labeled = table.concat(marks_by_line[0] or {}, ",")
-- 第 21 行同样是 "21 abc21"，文本列与第 1 行完全一致（这正是补齐序号的点）
local unlabeled = table.concat(marks_by_line[20] or {}, ",")
check(labeled == "4,5,6", "第 1 行高亮列应为 4,5,6，实际 " .. labeled)
check(unlabeled == "4,5,6", "第 21 行高亮列也应为 4,5,6，实际 " .. unlabeled)
-- 快照时已输入 "abc"，处于输入模式：序号压成注释色，不冒充快捷键
check(
	snap.label_hl[0] == "lib-menu-label-dim",
	"输入模式下序号应变暗，实际 " .. tostring(snap.label_hl[0])
)

for _, b in ipairs(vim.api.nvim_list_bufs()) do
	check(
		bufs_before[b] or not vim.api.nvim_buf_is_valid(b),
		"关菜单后不应遗留 scratch buffer: " .. tostring(b)
	)
end

-- 帮助浮窗也走一遍：'?' 开、Esc 收、Esc 关，buffer 同样不能漏
local orig_rk_help = menu._read_key
local hstep = 0
menu._read_key = function()
	hstep = hstep + 1
	local keys = { "?", kc("<Esc>"), kc("<Esc>") }
	return keys[hstep]
end
menu.select({ "a" }, { prompt = "Help: " }, function() end)
menu._read_key = orig_rk_help
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	check(
		bufs_before[b] or not vim.api.nvim_buf_is_valid(b),
		"关帮助浮窗后不应遗留 scratch buffer: " .. tostring(b)
	)
end

----------------------------------------------------------------------
-- 7. 接管 vim.ui.select
----------------------------------------------------------------------

local orig = vim.ui.select
menu.setup({ max_height = 10 })
check(menu.builtin ~= nil, "setup 应保留原始实现")
check(vim.ui.select ~= orig, "setup 后 vim.ui.select 应换成菜单实现")

local via_ui = { called = 0 }
feed("3")
vim.ui.select({ "one", "two", "three" }, { prompt = "Pick: " }, function(item)
	via_ui.called = via_ui.called + 1
	via_ui.item = item
end)
check(via_ui.called == 1 and via_ui.item == "three", "vim.ui.select 应走菜单并选中第 3 项")

-- 空列表：立刻回调 nil，不弹窗
local empty = { called = 0 }
vim.ui.select({}, {}, function(item)
	empty.called = empty.called + 1
	empty.item = item
end)
check(empty.called == 1 and empty.item == nil, "空列表应立刻回调 nil")

vim.ui.select = orig

----------------------------------------------------------------------
-- 13. gg / G：跳到首项 / 末项；g 后接其它键不作数
----------------------------------------------------------------------

local five = { "a", "b", "c", "d", "e" }

local r_gg = run(kc("<C-n>") .. kc("<C-n>") .. kc("<C-n>") .. "gg" .. kc("<CR>"), five)
check(r_gg.item == "a", "下移 3 次后按 gg 应回到首项，实际 " .. tostring(r_gg.item))

local r_G = run("G" .. kc("<CR>"), five)
check(r_G.item == "e", "按 G 应选中末项，实际 " .. tostring(r_G.item))

-- g 后接非 g：作废那个 g，后面的键按原语义处理（gj = 下移一次）
local r_gj = run("g" .. "j" .. kc("<CR>"), five)
check(r_gj.item == "b", "gj 应当作下移一次（g 不作数），实际 " .. tostring(r_gj.item))

-- 小写 g 回车：没有 gg，仍停在当前项
local r_g_cr = run(kc("<C-n>") .. "g" .. kc("<CR>"), five)
check(r_g_cr.item == "b", "单个 g 后接回车应保持当前项，实际 " .. tostring(r_g_cr.item))

----------------------------------------------------------------------
-- 14. 索引模式：<C-g> + 数字 + <CR>
----------------------------------------------------------------------

local many = {}
for i = 1, 40 do
	many[i] = ("item%02d"):format(i)
end

local r_idx = run(kc("<C-g>") .. "2" .. "1" .. kc("<CR>"), many)
check(r_idx.item == "item21", "索引模式敲 21 应选中第 21 项，实际 " .. tostring(r_idx.item))

-- 越界时 <CR> 不选、也不关菜单；选中行停在「最后有效的那一项」（99 越界 → 停在 9）
-- <Esc> 退回导航模式后 <CR> 选中的就是这一项
local r_bad = run(kc("<C-g>") .. "9" .. "9" .. kc("<CR>") .. kc("<Esc>") .. kc("<CR>"), many)
check(r_bad.item == "item09", "越界后 Esc 退出应选最后有效的第 9 项，实际 " .. tostring(r_bad.item))

-- <BS> 删一位后重新生效；<C-u> 清空后敲新的也生效
local r_bs = run(kc("<C-g>") .. "3" .. "9" .. kc("<BS>") .. kc("<CR>"), many)
check(r_bs.item == "item03", "39 退格成 3 应选中第 3 项，实际 " .. tostring(r_bs.item))
local r_cu = run(kc("<C-g>") .. "3" .. "9" .. kc("<C-u>") .. "7" .. kc("<CR>"), many)
check(r_cu.item == "item07", "<C-u> 清空后敲 7 应选中第 7 项，实际 " .. tostring(r_cu.item))

-- 输入模式里 <C-g> 转入索引模式，序号作用于**过滤后**的结果
local r_filtered = run("i" .. "m0" .. kc("<C-g>") .. "2" .. kc("<CR>"), { "m01", "x", "m02", "m03" })
check(r_filtered.item == "m02", "过滤后索引应作用于过滤结果，实际 " .. tostring(r_filtered.item))

-- M-<pivot> 已移除：按 M-a 不再选第 10 项
local r_ma = run(kc("<M-a>") .. kc("<CR>"), many)
check(r_ma.item == "item01", "M-<pivot> 应已失效，实际 " .. tostring(r_ma.item))

----------------------------------------------------------------------
-- 15. 动画模式：opts.tick 超时推进帧号，format_item(item, frame) 拿到递增帧
----------------------------------------------------------------------
-- 15a. spinner 助手：帧号取模、无帧时回退到 base / 第一帧、自定义帧序列
local spin15 = menu.spinner()
check(spin15(nil, "◐") == "◐", "无帧时应回退到 base")
check(spin15(nil) == menu.frames[1], "无帧且没 base 时用第一帧")
check(spin15(0) == menu.frames[1] and spin15(1) == menu.frames[2], "帧号应从第一帧开始")
check(spin15(#menu.frames) == menu.frames[1], "帧号应对帧数取模（循环）")
local spin15b = menu.spinner({ "a", "b" })
check(spin15b(3) == "b" and spin15b(nil, "x") == "x", "自定义帧序列应生效")

local frames15 = {}
local idx15 = 0
local keys15 = { nil, nil, nil, kc("<CR>") }
local orig_rk15 = menu._read_key
menu._read_key = function()
	idx15 = idx15 + 1
	return keys15[idx15]
end
local chosen15
menu.select({ "busy", "idle" }, {
	prompt = "Anim: ",
	tick = true, -- 用 M.config.tick
	format_item = function(item, frame)
		frames15[#frames15 + 1] = frame
		return (frame and ("frame" .. frame) or "static") .. " " .. item
	end,
}, function(item)
	chosen15 = item
end)
menu._read_key = orig_rk15
check(chosen15 == "busy", "动画模式仍能正常选中（实际 " .. tostring(chosen15) .. "）")
check(#frames15 >= 6, "动画模式每帧都应重画，实际 format_item 调用 " .. #frames15 .. " 次")
local maxf15, monotone15 = 0, true
for _, f in ipairs(frames15) do
	if type(f) == "number" then
		maxf15 = math.max(maxf15, f)
	else
		monotone15 = false
	end
end
check(maxf15 >= 2, "帧号应递增（spinner 才会转），max=" .. maxf15)
check(monotone15, "动画模式下 format_item 每次都应拿到数字帧号")

----------------------------------------------------------------------
-- 收尾
----------------------------------------------------------------------

if #fails == 0 then
	print(
		"ok: 浮窗选择菜单（过滤/标签/键位/取消/单飞/滚动/锚点/接管 vim.ui.select）符合预期"
	)
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
