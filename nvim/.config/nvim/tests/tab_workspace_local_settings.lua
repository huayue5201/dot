-- 用户视角的行为测试：工作区本地配置 <根>/.nvim.lua（feat.tab_workspace.local_settings）。
--
--   nvim --headless -u NONE -l tests/tab_workspace_local_settings.lua
--
-- 只走用户会做的动作：进项目（:tcd）→ 打开文件 → 切到另一个项目 → 切回来。
-- 断言的原则只有一条：配置严格属于那个工作区，离开时逐项回到原值。
--
-- 覆盖：
--   * w.opt / w.global_opt 生效，且只作用于该根下的 buffer（根外的 buffer 不受影响）
--   * 之后新打开的文件也自动套用
--   * 切走工作区：buffer 选项、全局选项、用户命令、键位全部还原
--   * 切回来：重新生效
--   * 没有 .nvim.lua 的目录：什么都不做
--   * w.task 声明的任务出现在 overseer 模板列表里，离开后消失
--   * w.launch 声明的调试配置注入 dap.configurations，离开后摘除
--   * .nvim.lua 里写错语法：不炸编辑器，只报错，且不留下半套配置
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

local uv = vim.uv or vim.loop
local fails = {}
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

-- overseer / nvim-dap 是普通插件：把它们加进 rtp 才能在这里验证 D 层。
-- 没装的机器上跳过对应断言（不影响其余行为）。
local function add_plugin(dirname, module)
	local dir = vim.fn.expand("~/.local/share/nvim/site/pack/core/opt/") .. dirname
	if vim.fn.isdirectory(dir) ~= 1 then
		return false
	end
	vim.opt.rtp:append(dir)
	return pcall(require, module)
end
local has_overseer = add_plugin("overseer.nvim", "overseer")
local has_dap = add_plugin("nvim-dap", "dap")

local base = vim.fn.tempname() .. "-tw-local"
vim.fn.mkdir(base .. "/proj-a/src", "p")
vim.fn.mkdir(base .. "/proj-b", "p")
local A = real(base .. "/proj-a")
-- -u NONE 下取真实默认值，回滚后的期望值以它为准
local orig = { tabstop = vim.o.tabstop, expandtab = vim.o.expandtab, fillchars = vim.o.fillchars }
local B = real(base .. "/proj-b")

vim.fn.writefile({
	"w.opt({ tabstop = 7, expandtab = false })",
	'w.global_opt({ fillchars = "eob: " })',
	'w.cmd("WsBuild", function() vim.g.ws_built = (vim.g.ws_built or 0) + 1 end, {})',
	'w.map("n", "<leader>zz", "<cmd>WsBuild<cr>", { desc = "工作区构建" })',
	'w.task({ name = "工作区构建任务", cmd = { "make" }, cwd = "${workspaceFolder}" })',
	'w.launch({ name = "工作区调试", filetype = "lua", type = "nlua", request = "launch", program = "${workspaceFolder}/src/a.lua" })',
}, A .. "/.nvim.lua")
vim.fn.writefile({ "x" }, A .. "/src/a.lua")
vim.fn.writefile({ "y" }, B .. "/b.lua")

-- 测试环境里没有 :trust 交互：直接信任本地临时文件
local local_settings = require("feat.tab_workspace.local_settings")
local_settings._read = function(path)
	local lines = vim.fn.readfile(path)
	return table.concat(lines, "\n")
end
local_settings.setup()

-- 用户动作：进入 proj-a 并打开一个文件
vim.cmd.tcd(A)
vim.cmd.edit(A .. "/src/a.lua")
local buf_a = vim.api.nvim_get_current_buf()
local_settings.sync()

check(vim.bo[buf_a].tabstop == 7, "proj-a: tabstop 应为 7，实际 " .. tostring(vim.bo[buf_a].tabstop))
check(vim.bo[buf_a].expandtab == false, "proj-a: expandtab 应为 false")
check(vim.o.fillchars == "eob: ", "proj-a: 全局 fillchars 应生效，实际 " .. tostring(vim.o.fillchars))
check(vim.fn.exists(":WsBuild") == 2, "proj-a: :WsBuild 应存在")
local map = vim.fn.maparg("<leader>zz", "n", false, true)
check(type(map) == "table" and not vim.tbl_isempty(map), "proj-a: <leader>zz 应存在")

-- 之后新打开的文件同样套用
local buf_a2 = vim.fn.bufadd(A .. "/src/b.lua")
vim.fn.bufload(buf_a2)
vim.api.nvim_exec_autocmds("FileType", { buffer = buf_a2 })
check(vim.bo[buf_a2].tabstop == 7, "proj-a: 新打开的 buffer 也应套用 tabstop")

-- D 层：任务进 overseer 模板列表、调试配置进 dap.configurations
if has_overseer then
	local names, done = {}, false
	require("overseer.template").list({ dir = vim.fn.getcwd() }, function(tmpls)
		for _, t in ipairs(tmpls or {}) do
			names[t.name] = true
		end
		done = true
	end)
	vim.wait(2000, function()
		return done
	end)
	check(names["工作区构建任务"], "proj-a: 任务应出现在 overseer 模板列表")
end
if has_dap then
	local found
	for _, cfg in ipairs(require("dap").configurations.lua or {}) do
		if cfg.name == "工作区调试" then
			found = cfg
		end
	end
	check(found ~= nil, "proj-a: 调试配置应注入 dap.configurations")
	check(
		found and found.program == "${workspaceFolder}/src/a.lua",
		"proj-a: 调试配置里的 ${workspaceFolder} 应原样保留，交给 nvim-dap 运行时展开"
	)
end

-- 用户动作：切到 proj-b（那里没有 .nvim.lua）
vim.cmd.tcd(B)
vim.cmd.edit(B .. "/b.lua")
local_settings.sync()
check(
	vim.bo[buf_a].tabstop == orig.tabstop,
	"离开 proj-a: tabstop 应恢复成 " .. orig.tabstop .. "，实际 " .. tostring(vim.bo[buf_a].tabstop)
)
check(vim.bo[buf_a].expandtab == orig.expandtab, "离开 proj-a: expandtab 应恢复成 " .. tostring(orig.expandtab))
check(
	vim.o.fillchars == orig.fillchars,
	"离开 proj-a: 全局 fillchars 应恢复，实际 " .. tostring(vim.o.fillchars)
)
check(vim.fn.exists(":WsBuild") == 0, "离开 proj-a: :WsBuild 应被删除")
check(vim.fn.maparg("<leader>zz", "n") == "", "离开 proj-a: <leader>zz 应被删除")
if has_dap then
	for _, cfg in ipairs(require("dap").configurations.lua or {}) do
		check(cfg.name ~= "工作区调试", "离开 proj-a: 调试配置应被摘除")
	end
end
if has_overseer then
	local names, done = {}, false
	require("overseer.template").list({ dir = vim.fn.getcwd() }, function(tmpls)
		for _, t in ipairs(tmpls or {}) do
			names[t.name] = true
		end
		done = true
	end)
	vim.wait(2000, function()
		return done
	end)
	check(not names["工作区构建任务"], "离开 proj-a: 任务应消失")
end

-- 用户动作：切回 proj-a
vim.cmd.tcd(A)
vim.cmd.edit(A .. "/src/a.lua")
local_settings.sync()
check(vim.bo[buf_a].tabstop == 7, "回到 proj-a: tabstop 应重新为 7")
check(vim.fn.exists(":WsBuild") == 2, "回到 proj-a: :WsBuild 应重新存在")

-- 语法错误：只报错，不能留下半套配置
vim.fn.writefile({ "w.opt({ tabstop = 9 })", "w.opt({" }, A .. "/.nvim.lua")
local notified = false
vim.notify = function(msg, level)
	if level == vim.log.levels.ERROR and tostring(msg):find("workspace config", 1, true) then
		notified = true
	end
end
local_settings.reload()
check(notified, "语法错误应报错")
check(vim.bo[vim.api.nvim_get_current_buf()].tabstop == orig.tabstop, "语法错误时不应留下半套配置")

----------------------------------------------------------------------
-- 收尾
----------------------------------------------------------------------
vim.notify = orig_notify
pcall(vim.cmd.tcd, { args = { "/" } })
pcall(vim.fn.delete, base, "rf")

if #fails == 0 then
	print("ok: 工作区本地配置严格跟随工作区，离开即回滚")
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
