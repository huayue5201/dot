-- 用户视角：lib/menu（接管 vim.ui.select 的浮窗菜单）。
--
--   nvim --headless -u NONE -l tests/menu.lua
--
-- 覆盖：
--   1. 过滤：空查询返回全部、模糊命中带高亮位置、无命中为空
--   2. 标签：1-9 数字、10 起 M-<pivot>
--   3. 数字键直接选中、<C-n> 移动 + <CR> 选中
--   4. 输入字符过滤、<BS> 退格、<C-u> 清空
--   5. Esc 取消 → 回调 (nil, nil)
--   6. 单飞：菜单开着时第二次调用只返回 false，不叠第二层；结束后能再开
--   7. setup() 之后 vim.ui.select 走的是这个菜单；M.builtin 保留原实现
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

check(menu.label(1) == "1" and menu.label(9) == "9", "1-9 用数字标签")
check(menu.label(10) == "M-a" and menu.label(11) == "M-s", "第 10 项起用 M-<pivot>")
check(menu.line(2, "x") == "2 x", "行文本 = 标签 + 空格 + 内容")

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

r = run(kc("<M-s>"), { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l" })
check(r.item == "k", "M-s 应选中第 11 项，实际 " .. tostring(r.item))

----------------------------------------------------------------------
-- 5b. 提示文本在边框中间（含输入模式标记）
----------------------------------------------------------------------

local titles = {}
local orig_rk_title = menu._read_key
local title_reads = 0
menu._read_key = function()
	title_reads = title_reads + 1
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(w)
		if cfg.title then
			local parts = {}
			for _, chunk in ipairs(cfg.title) do
				parts[#parts + 1] = chunk[1]
			end
			titles[#titles + 1] = { text = table.concat(parts), pos = cfg.title_pos }
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
local last = titles[#titles]
check(
	last and last.text:find("Pick: g", 1, true) ~= nil,
	"输入模式下标题应带出当前查询，实际 " .. tostring(last and last.text)
)

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
-- 收尾
----------------------------------------------------------------------

if #fails == 0 then
	print("ok: 浮窗选择菜单（过滤/标签/键位/取消/单飞/接管 vim.ui.select）符合预期")
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
