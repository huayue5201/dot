-- 用户视角：终端是否跟随「工作区（多根）」。
--
--   nvim --headless -u NONE -l tests/terminal_workspace.lua
--
-- 覆盖：
--   1. 新终端的 cwd = 当前文件所属的根（辅助根里的文件 → 终端开在辅助根）
--   2. 文件在主根 / 没有文件名 → 回落到 tab 的根目录（主根）
--   3. 终端按 tab 隔离：切 tab 看不到别的 tab 的终端
--   4. 终端侧栏的组头显示「工作区名 +N」（N = 辅助根数量），空状态是英文
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

local uv = vim.uv or vim.loop
local fails = {}

local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

local function real(path)
	local ok, res = pcall(uv.fs_realpath, path)
	return (ok and res) or path
end

local base = vim.fn.tempname()
local A, B = base .. "/projA", base .. "/projB"
for _, dir in ipairs({ A, B }) do
	vim.fn.mkdir(dir .. "/src", "p")
	vim.fn.writefile({ "x" }, dir .. "/src/x.lua")
end

local tw = require("feat.tab_workspace")
tw.setup({ auto_root = false })

local term = require("feat.terminal")
term.setup({ startinsert = false, sidebar = true })

local roots = require("feat.tab_workspace.roots")
local tstate = require("feat.terminal.state")
local sidebar = require("feat.terminal.sidebar")

vim.notify = function() end

local function tab()
	return vim.api.nvim_get_current_tabpage()
end

local function edit(path)
	vim.cmd.edit({ args = { path } })
end

local function tcd(dir)
	vim.cmd.tcd({ args = { dir } })
end

local function term_cwd(bufnr)
	return real(vim.b[bufnr].tw_term_cwd or "")
end

----------------------------------------------------------------------
-- 1. 辅助根里的文件 → 终端开在辅助根
----------------------------------------------------------------------

tcd(A)
edit(A .. "/src/x.lua")
roots.attach(tab(), B)
edit(B .. "/src/x.lua")

local t_aux = term.new()
check(term_cwd(t_aux) == real(B), ("辅助根里的文件，新终端应在 projB，实际 %s"):format(term_cwd(t_aux)))

----------------------------------------------------------------------
-- 2. 主根 / 无名 buffer → 回落到 tab 根目录
----------------------------------------------------------------------

edit(A .. "/src/x.lua")
local t_main = term.new()
check(term_cwd(t_main) == real(A), ("主根里的文件，新终端应在 projA，实际 %s"):format(term_cwd(t_main)))

vim.cmd("enew")
local t_plain = term.new()
check(
	term_cwd(t_plain) == real(A),
	("无名 buffer，新终端应回落到 tab 根 projA，实际 %s"):format(term_cwd(t_plain))
)

----------------------------------------------------------------------
-- 2b. 从多根树的节点开终端（<C-t> 走的就是 M.new_for_node）
----------------------------------------------------------------------

local function fake_node(kind, path)
	return {
		type = kind,
		get_id = function()
			return path
		end,
	}
end

local t_node_file = term.new_for_node(fake_node("file", B .. "/src/x.lua"))
check(
	term_cwd(t_node_file) == real(B .. "/src"),
	("文件节点应开在所在目录，实际 %s"):format(term_cwd(t_node_file))
)

local t_node_dir = term.new_for_node(fake_node("directory", B))
check(term_cwd(t_node_dir) == real(B), ("目录节点应开在该目录，实际 %s"):format(term_cwd(t_node_dir)))

check(term.new_for_node(fake_node("directory", "workspace://roots")) == nil, "合成节点不应开终端")
check(term.new_for_node(nil) == nil, "没有节点时不应报错")

----------------------------------------------------------------------
-- 3. 终端按 tab 隔离
----------------------------------------------------------------------

local tab1 = tab()
check(#tstate.list(tab1) == 5, ("tab1 应有 5 个终端，实际 %d"):format(#tstate.list(tab1)))

vim.cmd.tabnew()
tcd(B)
edit(B .. "/src/x.lua")
local tab2 = tab()
check(#tstate.list(tab2) == 0, ("新 tab 不应看到别的 tab 的终端，实际 %d"):format(#tstate.list(tab2)))

local t2 = term.new()
check(#tstate.list(tab2) == 1, "新 tab 开的终端只登记在新 tab")
check(term_cwd(t2) == real(B), "新 tab 的终端应在 projB")

vim.cmd("tabprevious")
check(#tstate.list(tab()) == 5, "切回 tab1 后应只看到 tab1 的 5 个终端")

----------------------------------------------------------------------
-- 4. 侧栏组头：工作区名 + 辅助根数量；空状态英文
----------------------------------------------------------------------

local panel_win = vim.api.nvim_get_current_win()
local sbar = sidebar.open(panel_win, tab())
local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(sbar), 0, -1, false)
local header = lines[1] or ""
check(header:find("projA", 1, true) ~= nil, "侧栏组头应带工作区名 projA，实际: " .. header)
check(header:find("+1", 1, true) ~= nil, "侧栏组头应带辅助根数量 +1，实际: " .. header)

-- 关掉所有终端后：空状态文案（英文）
for _, b in ipairs(vim.api.nvim_list_bufs()) do
	if vim.b[b].tw_term and vim.api.nvim_buf_is_valid(b) then
		pcall(vim.api.nvim_buf_delete, b, { force = true })
	end
end
sidebar.render()
lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(sbar), 0, -1, false)
check(
	lines[1] == "No terminals",
	("没有终端时侧栏应显示 No terminals，实际: %s"):format(tostring(lines[1]))
)

----------------------------------------------------------------------
-- 5. <leader>Ts 重复按不会叠出第二个选择菜单
----------------------------------------------------------------------

local orig_select = vim.ui.select
local calls = 0

-- 模仿 dropbar：同步开出浮窗，取消（Esc）时不回调 on_choice
local menu_win = nil
vim.ui.select = function()
	calls = calls + 1
	local b = vim.api.nvim_create_buf(false, true)
	menu_win = vim.api.nvim_open_win(b, false, {
		relative = "editor",
		row = 1,
		col = 1,
		width = 12,
		height = 1,
		style = "minimal",
	})
end

-- 先造一个终端（前面把终端都删过了）
tcd(A)
edit(A .. "/src/x.lua")
local seed = term.new()
check(seed ~= nil, "应能新建终端")

term.select()
check(calls == 1, ("第一次按键应打开菜单，实际 %d"):format(calls))
term.select()
term.select()
check(calls == 1, ("菜单开着时重复按键不应再打开菜单，实际 %d"):format(calls))

vim.api.nvim_win_close(menu_win, true)
check(calls == 1, "关掉菜单本身不应触发新菜单")
term.select()
check(calls == 2, ("菜单关掉后再按键应重新打开，实际 %d"):format(calls))
if menu_win and vim.api.nvim_win_is_valid(menu_win) then
	vim.api.nvim_win_close(menu_win, true)
end

-- 会正常回调（选中/取消）的实现：立即解锁，不残留状态
vim.ui.select = function(_, _, cb)
	calls = calls + 1
	cb(nil)
end
local before_ok = calls
term.select()
term.select()
check(calls == before_ok + 2, "回调型实现不应被单飞锁住")

vim.ui.select = orig_select

----------------------------------------------------------------------
-- 收尾
----------------------------------------------------------------------

for _, b in ipairs(vim.api.nvim_list_bufs()) do
	if vim.b[b].tw_term and vim.api.nvim_buf_is_valid(b) then
		pcall(vim.api.nvim_buf_delete, b, { force = true })
	end
end
pcall(vim.cmd.tcd, { args = { "/" } })
pcall(vim.fn.delete, base, "rf")

if #fails == 0 then
	print("ok: 终端跟随工作区（辅助根 cwd / tab 隔离 / 侧栏组头）符合预期")
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
