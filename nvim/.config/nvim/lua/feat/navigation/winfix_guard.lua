-- 窗口尺寸守卫
--
-- 痛点：winfixwidth / winfixheight 只能拒绝 Neovim「新开窗口时的自动均分」，
-- 挡不住「关闭窗口时释放的空间被塞给另一个 winfix 窗口」。当同方向只剩
-- winfix 窗口、或插件自行重排布局时，目标窗口会被撑大，布局越关越乱。
--
-- 做法一（声明）：在 feat.navigation.settings 里为窗口声明期望尺寸，例如
--     ["sqmeow-drawer"] = { size = { width = 36 } },
--     ["sqmeow-result"] = { size = { height = 16 } },
-- 每次布局变化后，把这个窗口塞回期望尺寸，释放/需要的空间交给 Neovim
-- 分给「非目标窗口」（弹性窗口）。
--
-- 做法二（手动调整）：用户主动 resize 一个声明窗口时，记下这个尺寸作为该
-- 窗口的 override，之后关窗回滚到 override 而不是声明值；窗口关闭后 override
-- 失效，重新回到声明值。识别方式：WinResized 事件里，若没有伴随 WinNew /
-- WinClosed 等拓扑变化，且尺寸相对上次快照发生变化，就当作用户手动调整。
-- 额外用 vim.on_key 观察 <C-w>>,<C-w><,<C-w>+,<C-w>-,<C-w>=,<C-w>|,<C-w>_ 这类
-- resize 按键，命中就置一个 hint；hint 未过期时无视「拓扑变化后 500ms」的歧义
-- 窗口，直接判为用户意图。这样既保留被动观察的覆盖面，又消掉刚开窗就手动调的
-- 误回滚。
--
-- 只处理有声明/override 的窗口，不碰无声明窗口：否则会把别的插件（如
-- neo-tree）在临时布局下被挤压出的瞬时尺寸当成基线，关窗后强行拉回，
-- 反而和它们自己的布局恢复逻辑打架。

local M = {}

local api = vim.api

--- 声明式尺寸：key(filetype 或 buftype) -> { width?, height? }，值也可为函数。
---@type table<string, fun():table|table>
local declared = {}

--- 用户手动调整后的尺寸，优先于声明值。win -> { w?, h? }，窗口关闭即失效。
---@type table<integer, { w: integer|nil, h: integer|nil }>
local override = {}

--- 上次稳定后的尺寸快照，用来识别用户 resize：win -> { w, h }。
---@type table<integer, { w: integer, h: integer }>
local last = {}

--- 自己设置尺寸时置位，避免把自己触发的 WinResized 当成用户操作。
local applying = false

--- 观察回调去重：一批事件只跑一次。
local observing = false

--- 最近一次拓扑变化（开/关窗、切 tab、终端 resize）的时间戳。之后短暂窗口内的
--- WinResized 一律当作布局变化，不当成用户手动调整。
local last_topology = 0

--- 最近一次通过 resize 按键发起的用户调整的时间戳。命中它时无视拓扑时间戳，
--- 直接判定为用户意图。
local user_hint_at = 0

--- 可配置项（可通过 M.setup({ ... }) 覆盖）。
local config = {
	--- 拓扑变化后多久内视为「布局仍在稳定」，期间的尺寸变化回滚而非学习。
	settle_ms = 500,
	--- resize 按键 hint 的有效期。
	hint_ms = 1500,
}

--- 声明一个窗口的期望尺寸。size 可以是表或返回表的函数。
---@param key string filetype 或 buftype
---@param size table|fun():table
function M.declare(key, size)
	declared[key] = size
end

--- 从传入的 settings 表读取所有带 size 的条目（由 feat.navigation.setup 传入）。
local function load_declared(settings)
	declared = {}
	if type(settings) ~= "table" then
		return
	end
	for key, cfg in pairs(settings) do
		if type(cfg) == "table" and cfg.size then
			declared[key] = cfg.size
		end
	end
end

--- 解析 size（支持函数）。
---@return { width: integer|nil, height: integer|nil }|nil
local function resolve(size)
	if type(size) == "function" then
		local ok, res = pcall(size)
		return ok and res or nil
	end
	return size
end

--- 真正的普通窗口（排除浮窗）。
local function real(win)
	if not api.nvim_win_is_valid(win) then
		return false
	end
	return api.nvim_win_get_config(win).relative == ""
end

--- 窗口的匹配键：filetype 优先，否则 buftype。
local function key_of(win)
	local buf = api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	return ft ~= "" and ft or vim.bo[buf].buftype
end

--- 该 tab 内该维度是否存在「可接收空间的窗口」（非 winfix），没有的话空间无处可去，
--- 强行回滚只会被 Neovim 再次撑开，索性跳过。
---
--- 注意 skip：目标窗口自己不算「接收者」。把声明窗口拉回期望尺寸时，多出来的
--- 空间必须落在这个窗口之外 —— 若兄弟窗口全是 winfixheight，frame_setheight 拿不到
--- 空间就静默失败（外层 pcall 吞掉），声明窗口会卡在错误高度且再也回不去。
--- 所以「弹性」要按「除自己外还有没有人能接空间」判断，不能把自己算进去。
---@param tab integer
---@param dim "w"|"h"
---@param skip integer 目标窗口，不参与判断
---@return boolean
local function has_donor(tab, dim, skip)
	for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
		if win ~= skip and real(win) then
			local fixed = dim == "w" and vim.wo[win].winfixwidth or vim.wo[win].winfixheight
			if not fixed then
				return true
			end
		end
	end
	return false
end

--- 同一个 buffer 同时开在多个窗口里（典型是冻结表头：同一 buffer 拆出两行辅助窗口）时，
--- 声明尺寸该给哪个窗口没有答案，索性不碰：否则辅助窗口会被撑成主体尺寸，内容重复显示。
---@param win integer
---@return boolean
local function shared(win)
	return #vim.fn.win_findbuf(api.nvim_win_get_buf(win)) > 1
end

--- 某个窗口的期望尺寸：override 优先，其次声明值。
---@return integer|nil width, integer|nil height
local function desired(win)
	if shared(win) then
		return nil
	end
	local ov = override[win] or {}
	local size = declared[key_of(win)] and resolve(declared[key_of(win)]) or {}
	return ov.w or size.width, ov.h or size.height
end

--- 记录当前所有窗口尺寸，作为识别用户 resize 的基准。
local function snapshot()
	local seen = {}
	for _, tab in ipairs(api.nvim_list_tabpages()) do
		for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
			if real(win) then
				seen[win] = true
				last[win] = { w = api.nvim_win_get_width(win), h = api.nvim_win_get_height(win) }
			end
		end
	end
	-- 窗口消失后，快照与 override 一并清理：重开的窗口回到声明值。
	for win in pairs(last) do
		if not seen[win] then
			last[win] = nil
		end
	end
	for win in pairs(override) do
		if not seen[win] then
			override[win] = nil
		end
	end
end

--- 用户手动调整：无拓扑变化时，声明窗口相对快照变了，就把新尺寸记成 override。
local function learn()
	for _, tab in ipairs(api.nvim_list_tabpages()) do
		for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
			if real(win) and declared[key_of(win)] and not shared(win) then
				local prev = last[win]
				if prev then
					local w, h = api.nvim_win_get_width(win), api.nvim_win_get_height(win)
					local ov = override[win] or {}
					if w ~= prev.w then
						ov.w = w
					end
					if h ~= prev.h then
						ov.h = h
					end
					if ov.w or ov.h then
						override[win] = ov
					end
				end
			end
		end
	end
end

--- 按 override / 声明尺寸，把目标窗口塞回期望尺寸。
local function enforce()
	applying = true

	for _, tab in ipairs(api.nvim_list_tabpages()) do
		for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
			if real(win) then
				local want_w, want_h = desired(win)

				-- 每个窗口单独判断「谁能接空间」：目标窗口本身不算，否则在没有弹性
				-- 兄弟时会发起注定失败（pcall 静默）的 resize。
				if want_w and has_donor(tab, "w", win) and api.nvim_win_get_width(win) ~= want_w then
					pcall(api.nvim_win_set_width, win, want_w)
				end
				if want_h and has_donor(tab, "h", win) and api.nvim_win_get_height(win) ~= want_h then
					pcall(api.nvim_win_set_height, win, want_h)
				end
			end
		end
	end

	applying = false
end

---@param opts { settle_ms?: integer, hint_ms?: integer }|nil
---@param settings? table 带 size 的条目（feat.navigation.settings）
function M.setup(opts, settings)
	for k, v in pairs(opts or {}) do
		if config[k] ~= nil then
			config[k] = v
		end
	end
	load_declared(settings)

	local group = api.nvim_create_augroup("WinfixGuard", { clear = true })

	--- 拓扑变化：回滚到期望尺寸，并刷新快照。
	local function on_topology()
		last_topology = vim.uv.now()
		vim.schedule(function()
			if applying then
				return
			end
			enforce()
			snapshot()
		end)
	end

	--- 观察一次布局：刚发生拓扑变化就回滚，静止期则把用户改动记成 override。
	--- 合并同一批事件（observing 去重），避免重复调度。
	local function observe()
		if applying or observing then
			return
		end
		observing = true
		vim.schedule(function()
			observing = false
			if applying then
				return
			end
			local now = vim.uv.now()
			local hinted = now - user_hint_at < config.hint_ms
			if not hinted and now - last_topology < config.settle_ms then
				enforce()
			else
				learn()
				if hinted then
					user_hint_at = 0
				end
			end
			snapshot()
		end)
	end

	api.nvim_create_autocmd("WinClosed", {
		group = group,
		desc = "关窗后把目标窗口塞回期望尺寸",
		callback = function()
			on_topology()
		end,
	})

	api.nvim_create_autocmd({ "WinNew", "BufWinEnter", "TabEnter", "VimResized" }, {
		group = group,
		desc = "布局变化后刷新基线并强制期望尺寸",
		callback = function()
			on_topology()
		end,
	})

	-- WinResized 在部分环境（如 headless）不投递，所以额外用常见交互事件做
	-- 观察点：只要在拓扑变化之外观测到声明窗口尺寸变化，就当成用户手动调整。
	api.nvim_create_autocmd({ "WinResized", "WinEnter", "BufEnter", "ModeChanged", "CursorHold", "CursorHoldI" }, {
		group = group,
		desc = "区分用户手动 resize 与布局变化",
		callback = observe,
	})

	-- 不重映射任何按键，只旁路观察 <C-w> 后的 resize 键，置 hint。
	local resize_keys = { [">"] = true, ["<"] = true, ["+"] = true, ["-"] = true, ["="] = true, ["|"] = true, ["_"] = true }
	local pending_ctrl_w = false
	vim.on_key(function(key)
		if pending_ctrl_w then
			pending_ctrl_w = false
			if resize_keys[key] then
				user_hint_at = vim.uv.now()
			end
		elseif key == "\23" then -- CTRL-W
			pending_ctrl_w = true
		end
	end, api.nvim_create_namespace("WinfixGuardHint"))

	snapshot()
	enforce()
end

return M
