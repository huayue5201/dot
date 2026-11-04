-- 冒烟测试：自研模块能被 require、setup 之后注入点都接上了。
--
--   nvim --headless -l tests/smoke.lua
--
-- 不测试具体行为，只保证「重构断环之后，注入的缝还是通的」：
--   * feat.terminal.sidebar 拿到 host（close_icon / open / kill / hide）
--   * local.project 把 ask / chat 写进 store.actions
--   * 两个文件都不再有顶层回指（回指一旦被提到文件顶部就成环）
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

local fails = {}
local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

----------------------------------------------------------------------
-- feat.terminal ⇄ sidebar
----------------------------------------------------------------------

local terminal = require("feat.terminal")
local sidebar = require("feat.terminal.sidebar")

terminal.setup({})

check(type(sidebar.host) == "table", "sidebar.host 未注入（sidebar.setup(M) 没调用？）")
for _, name in ipairs({ "close_icon", "open", "kill", "hide" }) do
	check(type(sidebar.host[name]) == "function", "sidebar.host." .. name .. " 缺失")
end
-- 注入的必须是 init 里那批函数本体，不是另抄一份
check(sidebar.host and sidebar.host.kill == terminal.kill, "sidebar.host.kill 与 terminal.kill 不是同一函数")
check(sidebar.host and sidebar.host.open == terminal.open, "sidebar.host.open 与 terminal.open 不是同一函数")

----------------------------------------------------------------------
-- local.project → store.actions
----------------------------------------------------------------------

local project = require("local.project")
local store = require("local.project.store")

project.setup()

check(store.actions.ask == project.ask, "store.actions.ask 未指向 project.ask")
check(store.actions.chat == project.chat, "store.actions.chat 未指向 project.chat")
check(vim.fn.exists(":Project") == 2, ":Project 未注册")
check(vim.fn.exists(":ProjectAsk") == 2, ":ProjectAsk 未注册")
check(vim.fn.exists(":ProjectChat") == 2, ":ProjectChat 未注册")

----------------------------------------------------------------------
-- 静态：目标文件不得有顶层回指
----------------------------------------------------------------------

local function top_level_requires(path)
	local out = {}
	for _, line in ipairs(vim.fn.readfile(path)) do
		if line:match("^%S") then
			for mod in line:gmatch("require%s*%(?%s*[\"']([^\"']+)[\"']") do
				out[#out + 1] = mod
			end
		end
	end
	return out
end

local FORBIDDEN = {
	["lua/feat/terminal/sidebar.lua"] = "feat.terminal",
	["lua/local/project/ui.lua"] = "local.project",
}

for path, forbidden in pairs(FORBIDDEN) do
	local hit = false
	for _, mod in ipairs(top_level_requires(path)) do
		-- 允许 feat.terminal.state 这类子模块，只禁父模块本身
		if mod == forbidden then
			hit = true
		end
	end
	check(not hit, path .. ' 仍在顶层 require "' .. forbidden .. '"（提到顶部的回指会成环）')
end

----------------------------------------------------------------------

if #fails == 0 then
	print("ok: 注入点全部连通，无顶层回指")
	vim.cmd("qall!")
end

for _, msg in ipairs(fails) do
	io.stderr:write("FAIL " .. msg .. "\n")
end
io.stderr:write(("%d 项失败\n"):format(#fails))
vim.cmd("cq")
