-- 用户视角的行为测试：工作区重命名（feat.tab_workspace.root 的别名层）。
--
--   nvim --headless -u NONE -l tests/tab_workspace_name.lua
--
-- 覆盖：
--   * <leader>lwN 背后：设别名 → root.name() 返回别名，状态栏/选择器自动跟着变
--   * 别名按根目录（realpath）存，跨 tab 共享；不同目录互不影响
--   * 空串清除别名 → 回到 basename
--   * 首尾空白被裁掉
--   * 落盘：换一个进程读同一份文件也能拿到（这里用 forget_aliases 模拟重载）
--   * 改名只发 TabWorkspaceName，不发 TabWorkspaceRoot（不该触发 neo-tree 重扫）
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

local function mkdirp(path)
	vim.fn.mkdir(path, "p")
end

local function touch(path)
	local fd = assert(io.open(path, "a"))
	fd:close()
end

----------------------------------------------------------------------
-- 夹具
----------------------------------------------------------------------

local base = real(vim.fn.tempname())
local repo = base .. "/repo"
local other = base .. "/other"
mkdirp(repo .. "/.git")
touch(repo .. "/.git/HEAD")
mkdirp(other .. "/.git")
touch(other .. "/.git/HEAD")

local tw = require("feat.tab_workspace")
local root = require("feat.tab_workspace.root")

vim.notify = function(msg, level)
	notes[#notes + 1] = { msg = msg, level = level }
end
tw.setup({})

-- 别名文件指向临时目录，不污染真实 state
root.names_file(base .. "/names.json")

local root_events, name_events = 0, 0
local aug = vim.api.nvim_create_augroup("TestWsName", { clear = true })
vim.api.nvim_create_autocmd("User", {
	group = aug,
	pattern = "TabWorkspaceRoot",
	callback = function()
		root_events = root_events + 1
	end,
})
vim.api.nvim_create_autocmd("User", {
	group = aug,
	pattern = "TabWorkspaceName",
	callback = function()
		name_events = name_events + 1
	end,
})

pcall(vim.cmd.tcd, { args = { repo } })

----------------------------------------------------------------------
-- 1. 设别名 → name() 用别名
----------------------------------------------------------------------

check(root.name() == "repo", "默认名字应为目录 basename，实际 " .. root.name())
tw.set_workspace_name("我的项目")
check(root.name() == "我的项目", "改名后 name() 应返回别名，实际 " .. root.name())
check(root.alias() == "我的项目", "alias() 应返回别名，实际 " .. tostring(root.alias()))
check(name_events == 1, "改名应发一次 TabWorkspaceName，实际 " .. name_events)
check(root_events == 0, "改名不应发 TabWorkspaceRoot，实际 " .. root_events)

----------------------------------------------------------------------
-- 2. 首尾空白裁剪
----------------------------------------------------------------------

tw.set_workspace_name("  spaced  ")
check(root.name() == "spaced", "首尾空白应被裁掉，实际 [" .. root.name() .. "]")

----------------------------------------------------------------------
-- 3. 清除别名 → 回到 basename
----------------------------------------------------------------------

tw.set_workspace_name("")
check(root.name() == "repo", "清除别名后应回到 basename，实际 " .. root.name())
check(root.alias() == nil, "清除后 alias() 应为 nil")

----------------------------------------------------------------------
-- 4. 落盘 + 重新读取
----------------------------------------------------------------------

tw.set_workspace_name("persisted")
check(vim.fn.filereadable(base .. "/names.json") == 1, "别名应写入文件")
root.forget_aliases()
check(root.name() == "persisted", "重读文件后名字应仍是别名，实际 " .. root.name())

----------------------------------------------------------------------
-- 5. 按目录隔离 + 跨 tab 共享
----------------------------------------------------------------------

pcall(vim.cmd.tcd, { args = { other } })
check(root.name() == "other", "换目录后应回到该目录的 basename，实际 " .. root.name())
tw.set_workspace_name("另一个")

vim.cmd("tabnew")
local tab2 = vim.api.nvim_get_current_tabpage()
vim.api.nvim_set_current_tabpage(tab2)
pcall(vim.cmd.tcd, { args = { repo } })
check(root.name() == "persisted", "另一个 tab 回到同一目录应拿到同一别名，实际 " .. root.name())

vim.api.nvim_set_current_tabpage(1)
check(root.name() == "另一个", "原 tab 名字不应被新 tab 覆盖，实际 " .. root.name())

----------------------------------------------------------------------
-- 收尾
----------------------------------------------------------------------

vim.notify = orig_notify
pcall(vim.cmd.tcd, { args = { "/" } })
pcall(vim.fn.delete, base, "rf")

if #fails == 0 then
	print("ok: 工作区重命名行为符合预期")
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
