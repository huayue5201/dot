-- lua/local/ai/icons.lua
---@brief 每个 agent 一个图标：选择器/通知里一眼看出这是谁在回答。
--
-- 同一个后端里也可能跑着不同 agent（比如都从 tmux 里接），所以图标按「实例 id」
-- 优先、后端 id 次之的顺序解析。字形都在公共区或 Nerd Font 里，改完用 nr2char
-- 取，避免源码/同步过程把私有区字形弄坏——但这里是给人改的表，允许写字面量，
-- 只要求能显示出来。
--
-- 想换成某个 Nerd Font 字形：把对应项写成 vim.fn.nr2char(0xF0C0B) 这样的调用，
-- 或者直接改 setup({ icons = { pi = "π" } })。
local M = {}

--- 认不出来的 agent 用机器人：nf-md-robot（U+F06A9）
M.fallback = vim.fn.nr2char(0xF06A9)

local glyphs = {
	-- pi 的标识就是 π
	pi = "π",
	-- Claude Code 的 spinner 星号，也是它的产品标识
	claude = vim.fn.nr2char(0x273B),
	-- 终端里跑的其它命令行 agent：nf-fa-terminal
	generic = vim.fn.nr2char(0xF120),
}

---@param key string|nil
---@return string|nil
local function lookup(key)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	local icon = glyphs[key]
	if icon then
		return icon
	end
	-- "claude-code" / "claude_code" 这类 id 也认
	local base = key:lower():gsub("[^%w]+", "-"):match("^[%a]+")
	return base and glyphs[base] or nil
end

--- 取某个 agent 的图标；认不出来时给 fallback（不会返回 nil）
---@param key string|nil 实例 id 或后端 id
---@return string
function M.get(key)
	return lookup(key) or M.fallback
end

--- 没配置过就返回 nil（用于「要不要给默认图标」这种判断）
---@param key string|nil
---@return string|nil
function M.find(key)
	return lookup(key)
end

---@param map table<string, string>|nil
function M.setup(map)
	for k, v in pairs(map or {}) do
		if type(v) == "string" and v ~= "" then
			glyphs[k] = v
		end
	end
end

---@return table<string, string>
function M.all()
	return vim.deepcopy(glyphs)
end

return M
