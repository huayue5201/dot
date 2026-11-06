-- 用户视角的行为测试：会话保存/载入不会「存 A 打开成 B」（resession + tab_workspace）。
--
--   nvim --headless -u NONE -l tests/tab_workspace_session.lua
--
-- 覆盖：
--   * 载入 A 后去 B 干活：save_session / autosave 拒绝覆盖 A.json（归属校验）
--   * 同一项目内继续干活：正常保存
--   * 会话文件里的 global.cwd / tab.cwd 已失效：载入不抛 E344，仍能恢复
--   * tab 作用域会话载入复用当前 tab（不堆 tab），cwd 落到会话的根
--   * 归属导出为按 tab 顺序的数组（v2），tab 作用域只导出当前 tab
--   * 旧格式（tab 序号为键）仍能恢复归属
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

local pack = vim.fn.stdpath("data") .. "/site/pack/core/opt/resession.nvim"
if vim.fn.isdirectory(pack) == 1 then
	vim.opt.rtp:prepend(pack)
end

local ok_resession, resession = pcall(require, "resession")
if not ok_resession then
	print("skip: resession 未安装（" .. pack .. "）")
	vim.cmd("qall!")
	os.exit(0)
end

local uv = vim.uv or vim.loop
local fails = {}
local notes = {}
local orig_notify = vim.notify

local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

local function real(path)
	local ok, res = pcall(uv.fs_realpath, path)
	return (ok and res) or path
end

local function mkdirp(path)
	vim.fn.mkdir(path, "p")
end

local function touch(path)
	local fd = assert(io.open(path, "a"))
	fd:close()
end

local function cwd()
	return real(vim.fn.getcwd())
end

local function tabcount()
	return #vim.api.nvim_list_tabpages()
end

local function current_name()
	return vim.api.nvim_buf_get_name(0)
end

local base = vim.fn.tempname()
local A, B = base .. "/projA", base .. "/projB"
local sessions = base .. "/sessions"
mkdirp(A)
mkdirp(B)
mkdirp(sessions)
touch(A .. "/a1.txt")
touch(A .. "/a2.txt")
touch(B .. "/b1.txt")

-- 把 resession 的会话目录指到临时目录，绝不碰真实 ~/.local/share/nvim/session
local files = require("resession.files")
files.get_stdpath_filename = function(_, _)
	return sessions
end

local function session_path(name)
	return sessions .. "/" .. name .. ".json"
end

local function read_raw(name)
	local ok, data = pcall(function()
		local f = assert(io.open(session_path(name)))
		local s = f:read("*a")
		f:close()
		return vim.json.decode(s)
	end)
	return ok and data or nil
end

-- 安装和 lua/plugins/resession.lua 同款的 load 侧清洗，测试才走真实路径
local load_json_file = files.load_json_file
files.load_json_file = function(path)
	local data = load_json_file(path)
	if type(data) == "table" then
		pcall(require("feat.tab_workspace.session").strip_terminal_bufs, data)
		pcall(require("feat.tab_workspace.session_guard").sanitize_cwd, data)
	end
	return data
end

resession.setup({
	dir = "session",
	autosave = { enabled = false },
	load_detail = false,
	buf_filter = function(bufnr)
		return require("feat.tab_workspace.util").is_saved_buf(bufnr)
	end,
	extensions = { tab_workspace = { enable_in_tab = true } },
})

local tw = require("feat.tab_workspace")
tw.setup({ auto_root = false })
tw.attach_resession()

local guard = require("feat.tab_workspace.session_guard")
local workspace = require("feat.tab_workspace.workspace")
local session = require("feat.tab_workspace.session")
local state = require("feat.tab_workspace.state")

local function reset()
	pcall(vim.cmd, "silent! tabonly")
	pcall(vim.cmd, "enew!")
	local cur = vim.api.nvim_get_current_buf()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if b ~= cur and vim.api.nvim_buf_is_valid(b) then
			pcall(vim.api.nvim_buf_delete, b, { force = true })
		end
	end
	state.reset()
end

local function edit(path)
	vim.cmd.edit({ args = { path } })
end

local function tcd(dir)
	vim.cmd.tcd({ args = { dir } })
end

local warned = {}
vim.notify = function(msg, level)
	warned[#warned + 1] = { msg = msg, level = level }
end

----------------------------------------------------------------------
-- 1. 载入 A 后去 B 干活：不能把 B 写进 A.json
----------------------------------------------------------------------

reset()
tcd(A)
edit(A .. "/a1.txt")
resession.save("SA", { notify = false })
local before = read_raw("SA")
check(before ~= nil, "SA.json 应已写入")

tcd(B)
edit(B .. "/b1.txt")
warned = {}
workspace.save_session()
local after = read_raw("SA")

check(
	#after.buffers == #before.buffers,
	("跨项目 save_session 不应改写 SA 的 buffer（%d → %d）"):format(#before.buffers, #after.buffers)
)
check(real(after.tabs[1].cwd) == real(A), "SA 的 tab cwd 应仍是 projA，实际 " .. tostring(after.tabs[1].cwd))
local warned_guard = false
for _, w in ipairs(warned) do
	if w.level == vim.log.levels.WARN then
		warned_guard = true
	end
end
check(warned_guard, "拒绝覆盖时应给出 WARN 提示")

-- autosave 走同一条守卫：也不应覆盖
warned = {}
guard.autosave({ notify = false })
local after_auto = read_raw("SA")
check(#after_auto.buffers == #before.buffers, "autosave 也不应把 B 写进 SA")
check(#warned == 0, "autosave 被拒绝时应静默（不打扰）")

----------------------------------------------------------------------
-- 2. 同一项目内继续干活：正常保存
----------------------------------------------------------------------

reset()
tcd(A)
edit(A .. "/a1.txt")
resession.save("SB", { notify = false })
edit(A .. "/a2.txt")
workspace.save_session()
local sb = read_raw("SB")
check(#sb.buffers == 2, ("同项目内 save_session 应保存两个 buffer，实际 %d"):format(#sb.buffers))

----------------------------------------------------------------------
-- 3. 会话文件不存在：按新会话处理
----------------------------------------------------------------------

check(guard.fits("no_such_session") == true, "不存在的会话应允许写入")
check(guard.fits("SB") == true, "当前就在 projA，SB 应允许覆盖")

----------------------------------------------------------------------
-- 4. 会话里的目录已失效：载入不应抛 E344
----------------------------------------------------------------------

reset()
tcd(A)
edit(A .. "/a1.txt")
resession.save("SC", { notify = false })
local sc = read_raw("SC")
sc.global.cwd = base .. "/gone_global"
sc.tabs[1].cwd = base .. "/gone_tab"
local f = assert(io.open(session_path("SC"), "w"))
f:write(vim.json.encode(sc))
f:close()

reset()
tcd(B)
local ok_load, err = pcall(resession.load, "SC", { attach = false })
check(ok_load, "global.cwd 失效时 load 不应抛错: " .. tostring(err))
check(vim.fn.isdirectory(vim.fn.getcwd()) == 1, "载入后 cwd 应是有效目录，实际 " .. vim.fn.getcwd())
check(current_name():find("a1%.txt$") ~= nil, "应恢复 a1.txt，实际 " .. current_name())

----------------------------------------------------------------------
-- 5. tab 作用域会话：复用当前 tab，不堆 tab
----------------------------------------------------------------------

reset()
tcd(A)
edit(A .. "/a1.txt")
vim.cmd.tabnew()
tcd(B)
edit(B .. "/b1.txt")
resession.save_tab("TAB_S", { notify = false })
local scoped_data = read_raw("TAB_S")
check(scoped_data.tab_scoped == true, "TAB_S 应是 tab 作用域会话")
check(
	type(scoped_data.tab_workspace) == "table" and scoped_data.tab_workspace.scoped == true,
	"tab 作用域会话的归属应标记 scoped"
)
check(#(scoped_data.tab_workspace.list or {}) == 1, "tab 作用域会话只导出当前 tab 的归属")

vim.cmd("tabfirst")
local n0 = tabcount()
workspace.load_session("TAB_S", { attach = true })
check(
	tabcount() == n0,
	("载入 tab 作用域会话应复用当前 tab（期望 %d 个 tab，实际 %d）"):format(n0, tabcount())
)
check(cwd() == real(B), "载入后当前 tab 根应为 projB，实际 " .. cwd())
check(current_name():find("b1%.txt$") ~= nil, "载入后当前 buffer 应为 b1.txt，实际 " .. current_name())

workspace.load_session("TAB_S", { attach = true })
check(tabcount() == n0, "连续载入同一 tab 作用域会话不应堆 tab")

----------------------------------------------------------------------
-- 6. 归属导出格式：按 tab 顺序的数组
----------------------------------------------------------------------

reset()
tcd(A)
edit(A .. "/a1.txt")
local tab1 = vim.api.nvim_get_current_tabpage()
local buf1 = vim.api.nvim_get_current_buf()
state.claim(tab1, buf1)
vim.cmd.tabnew()
tcd(B)
edit(B .. "/b1.txt")
local tab2 = vim.api.nvim_get_current_tabpage()
local buf2 = vim.api.nvim_get_current_buf()
state.claim(tab2, buf2)

local exp = session.export()
check(exp.v == 2, "导出格式应为 v2，实际 " .. tostring(exp.v))
check(#exp.list == 2, ("应导出 2 个 tab，实际 %d"):format(#exp.list))
check(real(exp.list[1].root or "") == real(A), "第一项根应为 projA，实际 " .. tostring(exp.list[1].root))
check(real(exp.list[2].root or "") == real(B), "第二项根应为 projB，实际 " .. tostring(exp.list[2].root))
check(#exp.list[1].names == 1 and real(exp.list[1].names[1]) == real(A .. "/a1.txt"), "第一项应含 a1.txt")

local scoped_exp = session.export(tab2)
check(scoped_exp.scoped == true, "指定 tabpage 导出应标记 scoped")
check(#scoped_exp.list == 1 and real(scoped_exp.list[1].root or "") == real(B), "scoped 导出只含该 tab")

----------------------------------------------------------------------
-- 7. v2 与旧格式的恢复
----------------------------------------------------------------------

state.reset()
check(session.restore(exp) == true, "v2 归属应能恢复")
check(state.is_owned(tab1, buf1), "v2：tab1 应拥有 a1")
check(state.is_owned(tab2, buf2), "v2：tab2 应拥有 b1")

-- 旧格式：{ ["1"] = { "文件名" } }
state.reset()
local legacy = { ["1"] = { vim.api.nvim_buf_get_name(buf1) } }
check(session.restore(legacy) == true, "旧格式归属应能恢复")
check(state.is_owned(vim.api.nvim_list_tabpages()[1], buf1), "旧格式：tab1 应拥有 a1")

----------------------------------------------------------------------
-- 收尾
----------------------------------------------------------------------

vim.notify = orig_notify
pcall(vim.cmd.tcd, { args = { "/" } })
pcall(vim.fn.delete, base, "rf")

if #fails == 0 then
	print("ok: 会话保存/载入不会再「存 A 打开成 B」")
	if #notes > 0 then
		for _, n in ipairs(notes) do
			print("note: " .. n)
		end
	end
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
