-- smart-splits.nvim 的 Rex 后端（v3 协议）。
--
-- 上游 v3 不再内置复用器后端，Rex 也没有官方实现，这里自维护一份。
-- 协议：smart-splits.nvim 仓库的 PROTOCOL.md。参照同目录
-- vendor/smart-splits-backend-herdr.lua 的结构写。
--
-- 由 lua/plugins/smart-splits.lua 里的
--   mux = { backend = { "vendor.smart-splits-backend-rex" } }
-- 按模块名加载。
--
-- Rex 与 herdr 的语义差异：
--   * move：Rex 的 session.focus_direction 只回 revision，不回「是否真的动了」，
--     所以必须自己比对调用前后的 focused_block_id；没变就返回 false，
--     把 at_edge（stop/wrap/split）交还给核心处理。
--   * resize：Rex 没有「边框移动 N 格」，只有 session.resize_pane 的绝对 ratio。
--     因此要从 session.view 的布局树里找出「我们这一侧的那条边界」，
--     把格数换算成 ratio 增量后整体重设。

local function rex_bin()
	local bin = vim.env.REX_BIN
	if bin ~= nil and bin ~= "" then
		return bin
	end
	local dir = vim.env.REX_BIN_DIR
	if dir ~= nil and dir ~= "" then
		return dir .. "/rex"
	end
	return "rex"
end

local function session_id()
	local id = vim.env.REX_SESSION
	return (id ~= nil and id ~= "") and id or nil
end

local function block_id()
	local id = vim.env.REX_BLOCK
	return (id ~= nil and id ~= "") and id or nil
end

--- 运行 rex 并解析 JSON 输出；任何失败都返回 nil（协议要求绝不抛错）。
---@param args string[]
---@return table|nil
local function exec_json(args)
	local argv = { rex_bin() }
	vim.list_extend(argv, args)

	local ok, res = pcall(function()
		-- Rex 走 unix socket，实测单次调用 ~25ms；给足余量以容忍远端 server。
		return vim.system(argv, { text = true, timeout = 800 }):wait()
	end)
	if not ok or res == nil or res.code ~= 0 or res.stdout == nil or #res.stdout == 0 then
		return nil
	end

	local decoded_ok, decoded = pcall(vim.json.decode, res.stdout)
	if not decoded_ok then
		return nil
	end
	return decoded
end

--- 调用一个带 session_id 的服务端方法。
---@param method string
---@param args table
---@return table|nil
local function api_call(method, args)
	local sid = session_id()
	if sid == nil then
		return nil
	end
	args.session_id = sid
	local ok, encoded = pcall(vim.json.encode, args)
	if not ok then
		return nil
	end
	return exec_json({ "api", "call", "-s", sid, method, encoded })
end

---@return table|nil
local function get_view()
	local sid = session_id()
	if sid == nil then
		return nil
	end
	return exec_json({ "api", "call", "-s", sid, "session.view", vim.json.encode({ session_id = sid }) })
end

---@param view table
---@param id string
---@return table|nil window
local function find_window(view, id)
	for _, win in ipairs(view.windows or {}) do
		for _, layer in ipairs(win.layers or {}) do
			for _, blk in ipairs(layer.blocks or {}) do
				if blk.block_id == id then
					return win
				end
			end
		end
	end
	return nil
end

--- 窗口里被 tiled 布局承载的根节点（浮动层不参与边框调整）。
---@param win table
---@return table|nil
local function tiled_layout(win)
	for _, layer in ipairs(win.layers or {}) do
		if layer.kind == "tiled" then
			return layer.layout
		end
	end
	return nil
end

--- 在布局树里定位某个 block，返回它的叶节点和从根到它的路径。
--- 路径只收录「我们走下来时经过的 split」：{ node = <split 所在节点>, side = "before"|"after" }，
--- 顺序为从根到叶。
---@param node table
---@param id string
---@param path? table[]
---@return table|nil leaf, table path
local function locate(node, id, path)
	path = path or {}
	if node == nil then
		return nil, path
	end
	if node.block_id ~= nil then
		return node.block_id == id and node or nil, path
	end
	local split = node.split
	if split == nil then
		return nil, path
	end
	path[#path + 1] = { node = node, side = "before" }
	local leaf = locate(split.before, id, path)
	if leaf ~= nil then
		return leaf, path
	end
	path[#path] = { node = node, side = "after" }
	leaf = locate(split.after, id, path)
	if leaf ~= nil then
		return leaf, path
	end
	path[#path] = nil
	return nil, path
end

--- 收集子树里的叶子（含各自的 rect），用于找贴着边框的那个 block。
---@param node table
---@param out? table[]
---@return table[]
local function leaves(node, out)
	out = out or {}
	if node == nil then
		return out
	end
	if node.block_id ~= nil then
		out[#out + 1] = node
		return out
	end
	if node.split ~= nil then
		leaves(node.split.before, out)
		leaves(node.split.after, out)
	end
	return out
end

--- 从 path 里挑出「离我们最近的那条对应方向的边界」。
--- 左/上边界：我们在该 split 的 after 侧；右/下边界：我们在 before 侧。
---@param path table[]
---@param direction "left"|"right"|"up"|"down"
---@return table|nil entry { node = <split 节点>, side = "before"|"after" }
local function border_split(path, direction)
	local horizontal = direction == "left" or direction == "right"
	local want_side = (direction == "left" or direction == "up") and "after" or "before"
	local found = nil
	for _, entry in ipairs(path) do
		local split = entry.node.split
		if split ~= nil then
			local matches = (split.direction == "horizontal") == horizontal
			if matches and entry.side == want_side then
				found = entry -- 越深的越贴近，直接覆盖
			end
		end
	end
	return found
end

---@class RexBackend
local M = {
	name = "rex",
	protocol_version = "3.0.0",
}

--- 协议要求：便宜、无副作用、不 shell out。
--- 只认具体值：外部遗留的 REX_SESSION="" 会被继承下来，而 Neovim 的 vim.env
--- 连空串都读成 nil，所以靠 `~= nil` 判空就行。
function M.detect()
	return session_id() ~= nil and block_id() ~= nil and vim.fn.executable(rex_bin()) == 1
end

---@param direction "left"|"right"|"up"|"down"
---@param opts? { at_edge?: "stop"|"wrap"|"split" }
function M.move(direction, opts)
	if not M.detect() then
		return false
	end
	local self_id = block_id()

	local view = get_view()
	if view == nil then
		return false
	end
	local win = find_window(view, self_id)
	if win == nil then
		return false
	end
	-- 只有自己所在窗口才是活动窗口时，session 的焦点才有意义；
	-- 否则移动焦点等于替用户切到别的 tab。
	if view.active_window_id ~= nil and win.window_id ~= view.active_window_id then
		return false
	end

	local before_focus = win.focused_block_id
	if before_focus ~= self_id then
		-- 焦点其实不在本 block（典型：nvim 在后台 tab）。先把焦点拉回来再做方向移动，
		-- 否则会用别人的位置算方向。
		api_call("session.focus_block", { block_id = self_id })
	end

	api_call("session.focus_direction", { direction = direction, wrap = false })

	local after = get_view()
	if after == nil then
		return false
	end
	local after_win = find_window(after, self_id)
	if after_win == nil then
		return false
	end
	return after_win.focused_block_id ~= before_focus
end

---@param direction "left"|"right"|"up"|"down"
---@param opts? { amount?: number }
function M.resize(direction, opts)
	if not M.detect() then
		return false
	end
	local self_id = block_id()

	local view = get_view()
	if view == nil then
		return false
	end
	local win = find_window(view, self_id)
	if win == nil then
		return false
	end
	local layout = tiled_layout(win)
	if layout == nil then
		return false
	end
	local leaf, path = locate(layout, self_id)
	if leaf == nil then
		return false
	end
	local entry = border_split(path, direction)
	if entry == nil then
		return false -- 该方向没有相邻 pane，交还核心处理 at_edge
	end
	local split = entry.node.split

	local horizontal = direction == "left" or direction == "right"
	local cells = horizontal and vim.o.columns or vim.o.lines
	if cells <= 0 then
		cells = 1
	end
	-- 我们自己的 rect 只占窗口的一部分：1 格 = rect 尺寸 / cells，换算到 split 的
	-- 空间还要再除以 split 节点自身的 rect 尺寸。
	local self_extent = horizontal and leaf.rect[3] or leaf.rect[4]
	local split_extent = horizontal and entry.node.rect[3] or entry.node.rect[4]
	local amount = (opts or {}).amount or 1
	if split_extent == nil or split_extent <= 0 or self_extent == nil then
		return false
	end
	local delta = (amount * self_extent / cells) / split_extent

	local ratio = split.ratio + ((direction == "right" or direction == "down") and delta or -delta)
	ratio = math.min(math.max(ratio, 0.05), 0.95)

	-- before/after 要传「贴着边框的那个 block」：子树时取最靠近边界的一片叶子。
	local before_leaves = leaves(split.before)
	local after_leaves = leaves(split.after)
	if #before_leaves == 0 or #after_leaves == 0 then
		return false
	end
	-- 右/下边界 = before 侧最靠右（下）的叶子；左/上边界 = after 侧最靠左（上）的叶子。
	local function far_edge(n)
		return horizontal and (n.rect[1] + n.rect[3]) or (n.rect[2] + n.rect[4])
	end
	local function near_edge(n)
		return horizontal and n.rect[1] or n.rect[2]
	end
	local before_block, after_block = before_leaves[1], after_leaves[1]
	for _, n in ipairs(before_leaves) do
		if far_edge(n) > far_edge(before_block) then
			before_block = n
		end
	end
	for _, n in ipairs(after_leaves) do
		if near_edge(n) < near_edge(after_block) then
			after_block = n
		end
	end

	api_call("session.resize_pane", {
		direction = split.direction,
		before_block_id = before_block.block_id,
		after_block_id = after_block.block_id,
		ratio = ratio,
	})

	-- 用 ratio 是否变化确认结果（服务端可能拒绝或 clamp）。
	local after_view = get_view()
	if after_view == nil then
		return false
	end
	local after_win = find_window(after_view, self_id)
	if after_win == nil then
		return false
	end
	local after_layout = tiled_layout(after_win)
	if after_layout == nil then
		return false
	end
	local _, after_path = locate(after_layout, self_id)
	local after_entry = border_split(after_path, direction)
	if after_entry == nil or after_entry.node.split == nil then
		return false
	end
	return math.abs(after_entry.node.split.ratio - split.ratio) > 1e-6
end

function M.health()
	local sid = session_id()
	if sid ~= nil then
		vim.health.ok(("REX_SESSION=%s; running inside Rex"):format(sid))
	else
		vim.health.info("REX_SESSION is not set; not running inside Rex")
	end
	if block_id() ~= nil then
		vim.health.ok(("REX_BLOCK=%s"):format(block_id()))
	else
		vim.health.info("REX_BLOCK is not set")
	end
	local bin = rex_bin()
	if vim.fn.executable(bin) == 1 then
		vim.health.ok(("rex executable found: %s"):format(bin))
	else
		vim.health.warn(("rex executable not found: %s"):format(bin))
	end
	if sid ~= nil then
		if get_view() ~= nil then
			vim.health.ok("session.view returned a layout")
		else
			vim.health.warn("session.view failed; rex CLI cannot reach the server")
		end
	end
end

return M
