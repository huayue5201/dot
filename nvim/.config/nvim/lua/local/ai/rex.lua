-- lua/local/ai/rex.lua
---@brief 读 rex（终端复用器）的分屏布局，把 agent 实例映射到终端里的具体格子。
--
-- 数据来源：`rex session inspect <session> --json`（实测 ~30ms），核心结构
--   { label, active_window_id, windows = { { window_id, layers = { { kind = "tiled",
--     layout = <node>, blocks = { ... } } } } }, blocks = { { block_id, label } } }
--   <node> = { block_id, rect = {x, y, w, h} }              -- 叶子：0~1 归一化
--          | { split = { direction, ratio, before, after } } -- 分支
--
-- nvim 进程自己在 rex 里时自带 REX_SESSION / REX_BLOCK 环境变量，据此就能定位
-- 「我正在看的那个 window」，再把这个 window 的叶子展平就是地图数据。
local M = {}

local CACHE_MS = 1500
local cache = {}

local function env(name)
	local v = vim.env[name]
	if type(v) ~= "string" or v == "" then
		return nil
	end
	return v
end

function M.session()
	return env("REX_SESSION")
end

function M.block()
	return env("REX_BLOCK")
end

--- 能不能用地图：在 rex 里 + rex 命令可用
function M.available()
	return M.session() ~= nil and vim.fn.executable("rex") == 1
end

--- 取一个 session 的 inspect 结果（短缓存，避免一次选择里反复起进程）
---@param session string|nil
---@return table|nil data, string|nil err
function M.inspect(session)
	session = session or M.session()
	if not session then
		return nil, "不在 rex 里（没有 REX_SESSION）"
	end
	local now = vim.uv.now()
	local hit = cache[session]
	if hit and now - hit.ts < CACHE_MS then
		return hit.data
	end
	local ok, res = pcall(function()
		return vim.system({ "rex", "session", "inspect", session, "--json" }, { text = true }):wait(2000)
	end)
	if not ok or not res or res.code ~= 0 then
		return nil, "rex session inspect 失败"
	end
	local decoded, data = pcall(vim.json.decode, res.stdout)
	if not decoded or type(data) ~= "table" then
		return nil, "rex 输出无法解析"
	end
	cache[session] = { ts = now, data = data }
	return data
end

local function flatten(node, out)
	if type(node) ~= "table" then
		return
	end
	if node.block_id then
		if node.rect then
			table.insert(out, { block_id = node.block_id, rect = node.rect })
		end
		return
	end
	local split = node.split
	if type(split) ~= "table" then
		return
	end
	flatten(split.before, out)
	flatten(split.after, out)
end

--- 展平一个 window 的所有层 → { { block_id, rect, kind }, ... }
--
-- 数组顺序就是叠放顺序：tiled 层在最底下，floating 层按数组顺序往上叠（越靠后
-- 越靠前，和 rex raise_layer/lower_layer 的顺序一致）。rect 已经是相对整个 window
-- 的绝对坐标（浮层把自己的 bounds 也写进了 rect），所以可以直接一层层覆盖着画。
---@param window table
---@return table[]
function M.panes(window)
	local out = {}
	for _, layer in ipairs((window or {}).layers or {}) do
		local kind = layer.kind or "tiled"
		if layer.layout then
			local layer_panes = {}
			flatten(layer.layout, layer_panes)
			for _, p in ipairs(layer_panes) do
				p.kind = kind
				table.insert(out, p)
			end
		end
	end
	return out
end

--- block_id → 标签（"lively-prairie" 之类）的查表
---@param data table
---@return table<string, string>
function M.labels(data)
	local out = {}
	local function collect(blocks)
		for _, b in ipairs(blocks or {}) do
			if b.block_id then
				out[b.block_id] = b.label
			end
		end
	end
	collect(data.blocks)
	for _, w in ipairs(data.windows or {}) do
		for _, layer in ipairs(w.layers or {}) do
			collect(layer.blocks)
		end
	end
	return out
end

--- nvim 自己所在的那个 window（找不到就退回 active window）
---@param session string|nil
---@return table|nil window, table|nil data, string|nil err
function M.current_window(session)
	local data, err = M.inspect(session)
	if not data then
		return nil, nil, err
	end
	local want = M.block()
	if want then
		for _, w in ipairs(data.windows or {}) do
			for _, p in ipairs(M.panes(w)) do
				if p.block_id == want then
					return w, data
				end
			end
		end
	end
	for _, w in ipairs(data.windows or {}) do
		if w.window_id == data.active_window_id then
			return w, data
		end
	end
	return (data.windows or {})[1], data
end

return M
