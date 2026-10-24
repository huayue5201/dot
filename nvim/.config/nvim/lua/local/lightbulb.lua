-- 轻量 code-action 提示（替代 nvim-lightbulb 的 float 模式）。
--
-- 行为：光标停下的行如果有 LSP code action，就在该行**上方**（上方没空间时下方）
-- 显示一个单宽 Nerd Font 灯泡（默认 `` nf-md-lightbulb）；光标一移动、滚动、
-- 改字就隐藏，等下一次停顿再现 —— 和 VS Code / 原插件的观感一致。
--
-- 为什么自己写：
--   * nvim-lightbulb 走 vim.lsp.util.open_floating_preview，会强塞 border/padding
--     并覆盖 win_opts（原配置里的 winblend/border 其实被它改写了）。
--   * 这里只有「复用同一个 win + 一个 1×1 的 scratch buffer」，透明靠
--     `winhl = Normal:BulbFloat`（该组 bg = "none"，背景不参与绘制），
--     比 'winblend'（UI-dependent 的伪透明、滚动时可能留残影）更干净。
--   * 位置用 relative = "cursor" + anchor：浮窗自己跟光标绑定，不用 screenpos 换算，
--     长行（行末在屏幕外）也不会被裁掉；水平方向对齐光标那一列（原插件行为），
--     上方无空间时翻到光标下方。
--
-- 触发：CursorHold / CursorHoldI（'updatetime' 已经负责空闲去抖，见 core/settings.lua），
-- 这里只额外做「同一行同一 changedtick 不重复请求」+ 请求取消，避免重请求型 server
-- （rust-analyzer / pyright）被反复打。
-- 光标一移动就隐藏灯泡，再次停下才重新判断 —— 不做每行灯泡（那需要 virt_text）。

local M = {}

local ns = vim.api.nvim_create_namespace("lightbulb_float")

-- 窗口背景组：只声明 bg = "none"，fg 留给字形自己的 hl（见下面 extmark）
vim.api.nvim_set_hl(0, "BulbFloat", { bg = "none", default = true })

local defaults = {
	text = "", -- nf-md-lightbulb（单宽）
	hl = "DiagnosticWarn", -- 字形颜色，跟随主题
	debounce = 120, -- CursorHold 之后再等一会儿（毫秒），防事件连发
	-- 水平位置："cursor" = 对齐光标所在的列（原插件行为，光标停在行中也跟着走）；
	-- "textoff" = 对齐本行首字符
	position = "cursor",
	zindex = 45,
	-- 查询前可以额外排除的 filetype
	exclude_ft = {},
}

local opts = vim.deepcopy(defaults)

----------------------------------------------------------------------
-- 状态
----------------------------------------------------------------------

local buf ---@type integer?
local win ---@type integer?

-- 当前已发出的请求，切换位置/离开 buffer 时取消
local pending = {} ---@type table[]   -- { client, id }

-- 上一行已知的结论：{ buf, lnum, tick, has }
local cache ---@type table?

-- 每次 check 递增，回调里比对，丢弃过期结果
local generation = 0

-- 位置锚 {buf, win, lnum}（为什么需要它见下面 on_move 的注释）
local anchor ---@type table?
local set_anchor ---@type fun(a: table?)

local debounce_timer = vim.uv.new_timer()
-- 「全部 server 都说没有 action」的兜底计时（和去抖计时必须分开）
local grace_timer = vim.uv.new_timer()

----------------------------------------------------------------------
-- 浮窗
----------------------------------------------------------------------

local function ensure_buf()
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false
	vim.bo[buf].undolevels = -1
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { opts.text })
	-- 字形颜色：hl 组名直接挂在 extmark 上，换主题自动跟随（不需要 ColorScheme 钩子）
	vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
		end_col = #opts.text,
		hl_group = opts.hl,
	})
	return buf
end

--- 关闭浮窗（buffer 保留复用，不删）
function M.hide()
	if win and vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, true)
	end
	win = nil
end

--- 浮窗坐标：锚在光标上（relative = "cursor"），默认在光标所在行的**上方**，
--- 上方没有可用行（光标在窗口第一行）时翻到下方——和原插件/IDE 的手感一致。
--- 水平方向对齐本行首字符（'number'/'signcolumn' 已由 textoff 计入），
--- 光标停在长行中间也不会跑到屏幕外或被裁掉。
---@return table { row, col, anchor }
local function float_pos()
	local info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
	local col = 0
	if opts.position ~= "cursor" then
		-- 从光标那一列往左退到首字符列：绝对是 textoff + 1 这一列，
		-- 横向滚动（'leftcol'）时也仍然锚在可见文本区的第一列
		col = info.textoff + 1 - vim.fn.wincol()
	end
	if vim.fn.winline() <= 1 then
		return { row = 1, col = col, anchor = "NW" } -- 上方没空间：放到光标下方一行
	end
	return { row = 0, col = col, anchor = "SW" } -- 底边贴光标行：占的是上一行
end

--- 显示灯泡（复用同一个 win）
function M.show()
	local pos = float_pos()
	local b = ensure_buf()
	local width = math.max(1, vim.fn.strdisplaywidth(opts.text))

	if win and vim.api.nvim_win_is_valid(win) then
		local ok = pcall(vim.api.nvim_win_set_config, win, {
			relative = "cursor",
			row = pos.row,
			col = pos.col,
			anchor = pos.anchor,
			width = width,
			height = 1,
		})
		if not ok then
			M.hide()
		end
		return
	end

	local ok, w = pcall(vim.api.nvim_open_win, b, false, {
		relative = "cursor",
		row = pos.row,
		col = pos.col,
		anchor = pos.anchor,
		width = width,
		height = 1,
		style = "minimal",
		border = "none",
		focusable = false,
		noautocmd = true,
		zindex = opts.zindex,
	})
	if not ok then
		return
	end

	win = w
	-- 背景完全透明：BulbFloat 的 bg = "none"，不是 winblend 混出来的
	vim.wo[win].winhl = "Normal:BulbFloat"
	vim.wo[win].wrap = false
	vim.wo[win].foldenable = false
	vim.wo[win].spell = false
end

----------------------------------------------------------------------
-- LSP 侧
----------------------------------------------------------------------

local function cancel_pending()
	for _, p in ipairs(pending) do
		pcall(function()
			p.client:cancel_request(p.id)
		end)
	end
	pending = {}
end

---@param bufnr integer
---@return table[]
local function action_clients(bufnr)
	local out = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		local ok, supports = pcall(client.supports_method, client, "textDocument/codeAction", bufnr)
		if ok and supports then
			out[#out + 1] = client
		end
	end
	return out
end

-- textDocument/range/context 一个都不能少：make_text_document_params 只给 uri，
-- lua_ls 之类会直接报 -32603（field 'textDocument' 为 nil）；character 又必须
-- 按 client 的 offset_encoding 换算，所以每个 client 单独建一份。
---@param bufnr integer
---@param client table
---@return table
local function request_params(bufnr, client)
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")
	local range = { start = params.position, ["end"] = vim.deepcopy(params.position) }
	params.position = nil
	params.range = range
	params.context = {
		triggerKind = 1,
		diagnostics = vim.diagnostic.get(bufnr, { lnum = range.start.line }),
	}
	return params
end

--- 这一行是否需要显示灯泡（会发请求）
local function check_actions()
	local bufnr = vim.api.nvim_get_current_buf()
	local lnum = vim.fn.line(".")
	local tick = vim.api.nvim_buf_get_changedtick(bufnr)
	set_anchor({ bufnr, vim.api.nvim_get_current_win(), lnum, vim.fn.col(".") })

	-- 同一行、内容没变、已有结论 → 直接复用，不重复请求
	if cache and cache.buf == bufnr and cache.lnum == lnum and cache.tick == tick then
		if cache.has then
			M.show()
		else
			M.hide()
		end
		return
	end

	local clients = action_clients(bufnr)
	if #clients == 0 then
		cache = nil
		M.hide()
		return
	end

	cancel_pending()
	generation = generation + 1
	local gen = generation

	local function on_result(has)
		if gen ~= generation then
			return -- 已过期（光标移动/又发了一次请求）
		end
		if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then
			M.hide()
			return
		end
		if vim.fn.line(".") ~= lnum then
			M.hide()
			return
		end
		cache = { buf = bufnr, lnum = lnum, tick = tick, has = has }
		if has then
			M.show()
		else
			M.hide()
		end
	end

	for _, client in ipairs(clients) do
		local pok, params = pcall(request_params, bufnr, client)
		if pok and params then
			local id = client:request("textDocument/codeAction", params, function(err, result)
				if err then
					return
				end
				local list = (type(result) == "table" and result) or {}
				if #list > 0 then
					on_result(true)
				end
			end, bufnr)
			if id then
				pending[#pending + 1] = { client = client, id = id }
			end
		end
	end

	-- 所有 client 都返回空/出错时，要有人负责隐藏：用一次性兜底
	-- （正常情况下一秒内会有结果；这里只处理「全部无 action」）
	local all_gen = gen
	grace_timer:stop()
	grace_timer:start(1200, 0, vim.schedule_wrap(function()
		if all_gen ~= generation then
			return
		end
		if cache and cache.tick == tick and cache.lnum == lnum then
			return
		end
		-- 没有任何 server 报「有 action」→ 记录为无并用 hide
		cache = { buf = bufnr, lnum = lnum, tick = tick, has = false }
		M.hide()
	end))
end

----------------------------------------------------------------------
-- 触发
----------------------------------------------------------------------

-- 位置锚：{buf, win, lnum}。Neovim 会在事件循环里补发 CursorMoved
-- （api 改光标、CursorHold 之后都会），同一个位置上的「假移动」不能把
-- 正在飞的请求作废，否则灯泡永远不显示。
local function cur_anchor()
	return {
		vim.api.nvim_get_current_buf(),
		vim.api.nvim_get_current_win(),
		vim.fn.line("."),
		vim.fn.col("."), -- 同一行里左右移动也要算作移动（灯泡跟着光标列）
	}
end

--- 两个锚是否同一位置
---@param a table?
---@param b table?
---@return boolean
local function same_anchor(a, b)
	if not a or not b then
		return false
	end
	for i = 1, 4 do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- 已排队但还没执行的检查目标 {buf, win, lnum}：同一个位置重复收到事件时
-- 不再重置计时器（否则 CursorHoldI/CursorMoved 连发会把灯泡永远推迟）
local scheduled ---@type table?

local function schedule_check()
	local a = cur_anchor()
	if same_anchor(scheduled, a) and debounce_timer:is_active() then
		return
	end
	scheduled = a
	generation = generation + 1
	local gen = generation
	debounce_timer:stop()
	debounce_timer:start(opts.debounce, 0, vim.schedule_wrap(function()
		scheduled = nil
		if gen ~= generation then
			return
		end
		check_actions()
	end))
end

set_anchor = function(a)
	anchor = a
end

-- 位置真正变了（或没动）才隐藏；只隐藏，**不**取消在飞的请求：
-- 旧结果由 generation 比对丢弃，真正需要 cancel 的只在新 check 发起时
-- （check_actions 开头）和 LspDetach。
local function on_move()
	local a = cur_anchor()
	if same_anchor(anchor, a) then
		return
	end
	set_anchor(a)
	M.hide_now()
end

-- 位置/内容不再可信的事件（滚动、改字、缩放、切走）：无条件隐藏
function M.hide_now()
	generation = generation + 1
	scheduled = nil
	debounce_timer:stop()
	grace_timer:stop()
	M.hide()
end

---@param user table?
function M.setup(user)
	opts = vim.tbl_deep_extend("force", defaults, user or {})

	if opts.text == "" then
		opts.text = vim.fn.nr2char(0xF0335) -- nf-md-lightbulb
	end

	local group = vim.api.nvim_create_augroup("LightbulbFloat", { clear = true })

	local excluded = function()
		local ft = vim.bo.filetype
		return vim.tbl_contains(opts.exclude_ft, ft) or vim.bo.buftype ~= ""
	end

	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
		group = group,
		callback = function()
			if excluded() then
				M.hide()
				return
			end
			schedule_check()
		end,
	})

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertLeave" }, {
		group = group,
		callback = function()
			if win then
				on_move()
			end
		end,
	})

	-- 视线离开：位置信息全失效，藏起来等下一次 CursorHold
	vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
		group = group,
		callback = function()
			set_anchor(nil)
			M.hide_now()
		end,
	})

	-- 内容变了（normal 模式里改完一行）：旧结论作废并重新判断
	vim.api.nvim_create_autocmd("TextChanged", {
		group = group,
		callback = function()
			set_anchor(nil)
			M.hide_now()
			schedule_check()
		end,
	})

	-- 插入模式下只管藏；打字停顿后的判断交给 CursorHoldI，不在每次改动都发请求
	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		callback = function()
			set_anchor(nil)
			M.hide_now()
		end,
	})

	-- 滚动/缩放一律隐藏，不跟随、不自动重算：等下一次 CursorHold 再出
	vim.api.nvim_create_autocmd({ "WinScrolled", "VimResized" }, {
		group = group,
		callback = function()
			set_anchor(nil)
			M.hide_now()
		end,
	})

	-- 进插入模式：光标要开始动了，先藏
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function()
			set_anchor(nil)
			M.hide_now()
		end,
	})

	-- server 上/下车都会让「有没有 action」的结论失效
	vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
		group = group,
		callback = function(args)
			if cache and cache.buf == args.buf then
				cache = nil
			end
			if vim.api.nvim_get_current_buf() == args.buf then
				set_anchor(nil)
				M.hide_now()
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function()
			cache = nil
			set_anchor(nil)
			M.hide_now()
		end,
	})
end

-- 调试/测试用
M._show = M.show
M._hide = M.hide
M._check = check_actions

return M
