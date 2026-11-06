-- 用户视角的行为测试：按当前文件自动切换 tab 根目录（feat.tab_workspace.root）。
--
--   nvim --headless -u NONE -l tests/tab_workspace_root.lua
--
-- 只走「用户会做的动作」：:edit 一个文件、:tcd、开新 tab、<leader>lws / lwr / lwR
-- 背后的 API，然后看 getcwd() 有没有变成用户期望的样子。
--
-- 覆盖：
--   * 最近的 marker 胜出（monorepo 子项目不会被压到 git 根）
--   * 文件已在当前根内 → 完全不动（无切换、无通知）
--   * 显式设根 = 锁定，自动逻辑不覆盖；解除锁定后恢复跟随
--   * 回退到上一个根并锁定，不会立刻被下一次 BufEnter 弹回去
--   * 跨 tab 隔离：一个 tab 切根不影响另一个 tab
--   * node_modules 里的 marker 不算根
--   * 特殊 buffer（无名 / nofile / terminal）不触发切根
--   * 会话加载期间不切根
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

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

---@param path string
local function mkdirp(path)
	vim.fn.mkdir(path, "p")
end

---@param path string
local function touch(path)
	local fd = assert(io.open(path, "a"))
	fd:close()
end

---@param path string
local function write(path, text)
	local fd = assert(io.open(path, "w"))
	fd:write(text)
	fd:close()
end

local function cwd()
	return real(vim.fn.getcwd())
end

local function cd(dir)
	vim.cmd.tcd({ args = { dir } })
end

local function edit(path)
	vim.cmd.edit({ args = { path } })
end

local function switched()
	for _, n in ipairs(notes) do
		if n.msg:find("^工作区根 → ") then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------
-- 夹具：一个 git 仓库，内含带自身 marker 的子项目，外加 node_modules
----------------------------------------------------------------------

local base = real(vim.fn.tempname())
local repo = base .. "/repo"
local sub = repo .. "/sub"
local plain = base .. "/plain"
local pkg = repo .. "/node_modules/pkg"

mkdirp(sub)
mkdirp(plain)
mkdirp(pkg .. "/src")
mkdirp(repo .. "/.git")
touch(repo .. "/.git/HEAD")
touch(repo .. "/b.lua")
touch(sub .. "/a.lua")
touch(sub .. "/.luarc.json")
touch(plain .. "/c.txt")
touch(pkg .. "/package.json")
touch(pkg .. "/src/x.js")

-- 真正的配置目录：让 setup 生效（autocmd 才会挂上）
local tw = require("feat.tab_workspace")
local root = require("feat.tab_workspace.root")
local util = require("feat.tab_workspace.util")

vim.notify = function(msg, level)
	notes[#notes + 1] = { msg = msg, level = level }
end

tw.setup({})

local function reset(dir)
	root.reset()
	notes = {}
	-- 先把 buffer 换成夹具外的无名 buffer，再回夹具目录，避免上一轮的 pin/buffer 干扰
	vim.cmd.enew({ bang = true })
	cd(dir)
end

----------------------------------------------------------------------
-- 1. marker 解析
----------------------------------------------------------------------

check(real(root.resolve(vim.fn.bufadd(repo .. "/b.lua"))) == real(repo), "repo/b.lua 的根应为 repo")
check(
	real(root.resolve(vim.fn.bufadd(sub .. "/a.lua"))) == real(sub),
	"repo/sub/a.lua 的根应为最近的 marker（sub）"
)
check(root.resolve(vim.fn.bufadd(plain .. "/c.txt")) == nil, "plain/c.txt 没有 marker，根应为 nil")
check(
	real(root.resolve(vim.fn.bufadd(pkg .. "/src/x.js"))) == real(repo),
	"node_modules 里的 package.json 不算根，应回落到 repo"
)

----------------------------------------------------------------------
-- 2. 文件在根外 → 自动切根
----------------------------------------------------------------------

reset(plain)
edit(repo .. "/b.lua")
check(cwd() == real(repo), "打开根外的文件应把 tab 根切到它的项目根（repo），实际 " .. cwd())
check(switched(), "切根后应有一条「工作区根 → 」通知")

----------------------------------------------------------------------
-- 3. 文件已在根内 → 完全不动（没有通知）
----------------------------------------------------------------------

reset(repo)
edit(sub .. "/a.lua")
check(cwd() == real(repo), "文件已在根内时不应切根，实际 " .. cwd())
check(not switched(), "文件已在根内时不应有任何切根通知")

----------------------------------------------------------------------
-- 4. 显式设根 = 锁定
----------------------------------------------------------------------

reset(plain)
tw.set_root(plain)
notes = {}
edit(repo .. "/b.lua")
check(cwd() == real(plain), "显式设根后自动逻辑不应覆盖它，实际 " .. cwd())
check(not switched(), "被锁定时不应有切根通知")

----------------------------------------------------------------------
-- 5. 解除锁定 → 恢复跟随
----------------------------------------------------------------------

tw.root_unpin()
check(cwd() == real(repo), "解除锁定后应立刻跟随当前文件切到 repo，实际 " .. cwd())

----------------------------------------------------------------------
-- 6. 回退并锁定
----------------------------------------------------------------------

check(tw.root_back() == true, "root_back 应成功")
check(cwd() == real(plain), "root_back 应回到切根前的 plain，实际 " .. cwd())
notes = {}
edit(repo .. "/b.lua")
check(cwd() == real(plain), "回退后应锁定，不应被下一次 BufEnter 弹回 repo，实际 " .. cwd())
check(not switched(), "回退锁定后不应再有切根通知")

----------------------------------------------------------------------
-- 7. 特殊 buffer 不触发
----------------------------------------------------------------------

reset(plain)
local specials = {
	{ name = "", buftype = "", label = "无名 buffer" },
	{ name = base .. "/scratch.md", buftype = "nofile", label = "nofile buffer" },
	{ name = "term://" .. plain .. "//12345:/bin/zsh", buftype = "", label = "term:// 命名的 buffer" },
}
for _, case in ipairs(specials) do
	local bufnr = vim.api.nvim_create_buf(false, true)
	if case.buftype ~= "" then
		vim.bo[bufnr].buftype = case.buftype
	end
	if case.name ~= "" then
		pcall(vim.api.nvim_buf_set_name, bufnr, case.name)
	end
	notes = {}
	cd(plain)
	pcall(vim.cmd.buffer, { args = { bufnr } })
	check(cwd() == real(plain), case.label .. " 不应触发切根，实际 " .. cwd())
	check(root.resolve(bufnr) == nil, case.label .. " 不应解析出根")
	vim.api.nvim_buf_delete(bufnr, { force = true })
end

-- 真终端 buffer：buftype == "terminal"，应被完全跳过
reset(plain)
local tbuf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(tbuf)
if pcall(vim.fn.termopen, { "/bin/sh", "-c", "true" }) then
	notes = {}
	cd(plain)
	pcall(vim.cmd.buffer, { args = { tbuf } })
	check(cwd() == real(plain), "terminal buffer 不应触发切根，实际 " .. cwd())
	check(root.resolve(tbuf) == nil, "terminal buffer 不应解析出根")
end
pcall(vim.api.nvim_buf_delete, tbuf, { force = true })

----------------------------------------------------------------------
-- 8. 会话加载期间不切根
----------------------------------------------------------------------

reset(plain)
local orig_loading = util.resession_loading
util.resession_loading = function()
	return true
end
edit(repo .. "/b.lua")
util.resession_loading = orig_loading
check(cwd() == real(plain), "会话加载期间不应切根，实际 " .. cwd())
check(not switched(), "会话加载期间不应有切根通知")

----------------------------------------------------------------------
-- 9. 跨 tab 隔离
----------------------------------------------------------------------

reset(repo)
local tab1 = vim.api.nvim_get_current_tabpage()
vim.cmd.tabnew()
local tab2 = vim.api.nvim_get_current_tabpage()
cd(sub)
edit(repo .. "/b.lua")
check(cwd() == real(repo), "tab2 打开 repo 的文件后 tab2 根应为 repo，实际 " .. cwd())
vim.api.nvim_set_current_tabpage(tab1)
check(
	real(vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(tab1))) == real(repo),
	"切回 tab1 后根应仍是 repo（各 tab 独立）"
)
check(real(vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(tab2))) == real(repo), "tab2 的根也应是 repo")
vim.api.nvim_set_current_tabpage(tab2)
vim.cmd.tabclose({ args = { vim.api.nvim_tabpage_get_number(tab2) } })

----------------------------------------------------------------------
-- 10. 配置开关
----------------------------------------------------------------------

reset(plain)
tw.setup({ auto_root = false })
edit(repo .. "/b.lua")
check(cwd() == real(plain), "auto_root = false 时不应自动切根，实际 " .. cwd())
tw.setup({ auto_root = true })
edit(repo .. "/b.lua")
check(cwd() == real(repo), "auto_root 恢复后应重新跟随，实际 " .. cwd())

----------------------------------------------------------------------
-- 收尾
----------------------------------------------------------------------

vim.notify = orig_notify
pcall(vim.cmd.tcd, { args = { "/" } })
pcall(vim.fn.delete, base, "rf")

if #fails == 0 then
	print("ok: tab 根目录自动跟随行为符合预期")
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
