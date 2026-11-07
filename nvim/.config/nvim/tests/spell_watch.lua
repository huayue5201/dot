-- 用户视角的行为测试：原生 zg/zw 改完词典，spellwand 诊断要自己跟上（feat.spell.watch）。
--
--   nvim --headless -u NONE -l tests/spell_watch.lua
--
-- 覆盖：
--   * spellfile（en.utf-8.add）被原子替换写入 → 触发一次 spellwand.refresh
--   * 目录里其它文件变化不触发（不能把 mkspell 自己的 .add.spl 回写当信号，否则死循环）
--   * stop() 之后不再触发
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

local fails = {}
local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local add = dir .. "/en.utf-8.add"
vim.fn.writefile({ "neovim" }, add)

local hits = 0
package.loaded["spellwand"] = {
	refresh = function()
		hits = hits + 1
	end,
}

local spell = require("feat.spell")
local handle = spell.watch({ dir = dir, add = add, debounce = 40 })
check(handle ~= nil, "watch() 应返回 handle")

-- 1. 正常写入（writefile 是原子 rename，与 Neovim 写 .add 的方式一致）
vim.fn.writefile({ "neovim", "tabline" }, add)
check(vim.wait(3000, function()
	return hits > 0
end, 20), "add 文件变化后应调用 spellwand.refresh")

-- 2. 同目录的其它文件不该触发
local before = hits
vim.fn.writefile({ "x" }, dir .. "/notes.txt")
vim.wait(400)
check(hits == before, "非 spellfile 的变化不应触发刷新")

-- 3. stop 之后不再触发
handle.stop()
vim.fn.writefile({ "neovim", "tabline", "floatwin" }, add)
vim.wait(400)
check(hits == before, "stop() 之后不应再触发刷新")

vim.fn.delete(dir, "rf")

if #fails > 0 then
	for _, msg in ipairs(fails) do
		io.stderr:write("FAIL: " .. msg .. "\n")
	end
	os.exit(1)
end
print("ok: zg/zw 改词典会刷新 spellwand 诊断，且只在 spellfile 变化时触发")
