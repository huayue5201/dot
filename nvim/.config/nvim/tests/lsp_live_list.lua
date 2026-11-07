-- 用户视角的行为测试：grd / grD 打开的诊断列表会随诊断变化就地刷新（lsp_ext.live_list）。
--
--   nvim --headless -u NONE -l tests/lsp_live_list.lua
--
-- 覆盖：
--   * grd 的 loclist：错误修好后条目消失；清空后窗口仍在、列表为空
--   * grD 的 quickfix：不再受 8 秒窗口限制，诊断变化后条目跟着变
--   * 列表被别的来源覆盖（标题变了）→ 停止监听，不再覆盖别人的列表
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

local fails = {}
local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

local actions = require("lsp_ext.actions")
local ns = vim.api.nvim_create_namespace("live_list_test")

local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = 1", "local y = 2" })
vim.api.nvim_win_set_buf(0, buf)
local file_win = vim.api.nvim_get_current_win()

local function diag(lnum, msg)
	return {
		lnum = lnum,
		col = 0,
		message = msg,
		severity = vim.diagnostic.severity.ERROR,
		source = "test",
	}
end

local function wait(cond)
	return vim.wait(3000, cond, 20)
end

----------------------------------------------------------------------
-- grd：loclist 就地刷新
----------------------------------------------------------------------
vim.diagnostic.set(ns, buf, { diag(0, "err one"), diag(1, "err two") })
actions.open_buffer_diagnostics()

local loc_win
for _, win in ipairs(vim.api.nvim_list_wins()) do
	local info = vim.fn.getwininfo(win)[1]
	if info and info.loclist == 1 and vim.fn.getloclist(win, { title = 1 }).title == "Buffer Diagnostics" then
		loc_win = win
	end
end
check(loc_win ~= nil, "grd 应打开 loclist 窗口")
check(#(vim.fn.getloclist(loc_win or 0, { items = 1 }).items or {}) == 2, "grd 初始应有 2 条")

-- 在列表窗口里再按一次 grd：目标应是来源文件窗口，不是 qf buffer（否则列表会被清空）
vim.api.nvim_set_current_win(loc_win)
actions.open_buffer_diagnostics()
check(wait(function()
	return #(vim.fn.getloclist(loc_win, { items = 1 }).items or {}) == 2
end), "从列表窗口再按 grd 不应把列表清空")

-- 修好第一条 → 列表应只剩一条
vim.diagnostic.set(ns, buf, { diag(1, "err two") })
check(wait(function()
	return #(vim.fn.getloclist(loc_win, { items = 1 }).items or {}) == 1
end), "修好一条后 loclist 应实时少一条")

-- 全部修好 → 列表为空，但窗口保留
vim.diagnostic.reset(ns, buf)
check(wait(function()
	return #(vim.fn.getloclist(loc_win, { items = 1 }).items or {}) == 0
end), "全部修好后 loclist 应为空")
check(vim.api.nvim_win_is_valid(loc_win), "清空后 loclist 窗口应保留")

-- 光标锚定：删掉前面的条目后，光标应跟着原来那条走而不是行号漂移
vim.diagnostic.set(ns, buf, { diag(0, "a"), diag(1, "b"), diag(2, "c") })
vim.api.nvim_set_current_win(file_win) -- :lwindow 会把光标切到列表窗口
actions.open_buffer_diagnostics()
for _, win in ipairs(vim.api.nvim_list_wins()) do
	local info = vim.fn.getwininfo(win)[1]
	if info and info.loclist == 1 and vim.fn.getloclist(win, { title = 1 }).title == "Buffer Diagnostics" then
		loc_win = win
	end
end
vim.api.nvim_win_set_cursor(loc_win, { 3, 0 })
vim.diagnostic.set(ns, buf, { diag(1, "b"), diag(2, "c") })
check(wait(function()
	return #(vim.fn.getloclist(loc_win, { items = 1 }).items or {}) == 2
end), "删掉一条后 loclist 应剩 2 条")
local cur = vim.api.nvim_win_get_cursor(loc_win)[1]
local cur_item = vim.fn.getloclist(loc_win, { items = 1 }).items[cur]
check(cur_item ~= nil and cur_item.lnum == 3, "光标应锚回原来那条（lnum=3），实际: " .. tostring(cur_item and cur_item.lnum))

----------------------------------------------------------------------
-- grD：quickfix 常驻刷新（不再有 8 秒窗口）
----------------------------------------------------------------------
vim.diagnostic.set(ns, buf, { diag(0, "err one") })
vim.api.nvim_set_current_win(file_win)
actions.open_all_diagnostics()

local function qf_items()
	return vim.fn.getqflist({ items = 1 }).items or {}
end
check(vim.wait(3000, function()
	return #qf_items() == 1
end, 20), "grD 初始应有 1 条")

vim.diagnostic.set(ns, buf, { diag(0, "err one"), diag(1, "err two") })
check(vim.wait(3000, function()
	return #qf_items() == 2
end, 20), "grD 的诊断列表应随之增加")

vim.diagnostic.reset(ns, buf)
check(vim.wait(3000, function()
	return #qf_items() == 0
end, 20), "grD 的错误修好后条目应实时消失（超过 8 秒也一样）")

-- grd 的 loclist 与 grD 的 qf 各有一份监听，应同时刷新
check(vim.api.nvim_win_is_valid(loc_win), "loclist 窗口应仍然存在")
check(vim.wait(3000, function()
	return #(vim.fn.getloclist(loc_win, { items = 1 }).items or {}) == 0
end, 20), "grd 的 loclist 应与 grD 的 qf 同时实时刷新")

----------------------------------------------------------------------
-- 列表被别的来源覆盖 → 停止监听，不覆盖别人的列表
----------------------------------------------------------------------
vim.fn.setqflist({}, " ", { title = "Something Else", items = { { filename = "x", lnum = 1 } } })
vim.diagnostic.set(ns, buf, { diag(0, "err three") })
vim.wait(600)
local title = vim.fn.getqflist({ title = 1 }).title
check(title == "Something Else", "列表被覆盖后不应再写回（实际标题: " .. tostring(title) .. "）")
check(#qf_items() == 1, "别人的 qf 列表不应被改写")

vim.diagnostic.reset(ns, buf)

if #fails > 0 then
	for _, msg in ipairs(fails) do
		io.stderr:write("FAIL: " .. msg .. "\n")
	end
	os.exit(1)
end
print("ok: grd/grD 的诊断列表会随诊断实时刷新，且不覆盖别人的列表")
