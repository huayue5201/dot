---code lens 渲染 / 鼠标点击 / 悬停高亮
---
---背景：Neovim 0.13 的 `vim.lsp.codelens.enable` 能渲染透镜（▶ Run / ⚙ Debug），
---但它把高亮组硬编码为 `LspCodeLens` / `LspCodeLensSeparator`，无法在鼠标悬停到
---某个透镜时给出反馈。这里改为自己请求并渲染透镜，从而支持：
---  1. 鼠标悬停到某个透镜 → 该透镜高亮（CodeLensHover）
---  2. 鼠标点击透镜 → 执行（等价于 lens.command）
---服务端协议不变（textDocument/codeLens + codeLens/resolve）。
---注意：启用本模块后不要再调用 `vim.lsp.codelens.enable`，否则两套渲染会互相覆盖。
---执行入口：`grx`（lua/lsp-config/keys.lua，内建 code lens 键位）→
---`actions.run_code_lens()` → `M.run_at_cursor()`。
---内建 `vim.lsp.codelens.run()`（内建自带的映射键）仍可独立工作（会自行请求一次），
---但它不认 above 布局的虚拟行偏移，所以键位上覆盖掉了。
---
---渲染位置、黑名单、逐条过滤见 `M.config`。

local M = {}

---可配置项（直接在这里改，或调用 M.configure({...}) 覆盖）
M.config = {
	-- 渲染位置：
	--   "above"  目标行上方、独立一屏行，按该行缩进对齐（同 VSCode codelens）（默认）
	--   "below"  目标条目下方（锚在 range 结束行，即函数结束之后）
	--   "inline" 行首、代码左侧（虚拟文本内联，代码被右移）
	--   "eol"    目标行行尾（virt_text_pos=eol，会被窗口右边缘截断，不能横向滚动）
	placement = "above",
	-- 虚拟行（above/below）超出窗口宽度时的行为：
	--   "auto" 由 'wrap' 决定（默认，与 VSCode 跟随编辑器折行设置一致）| "trunc" 右端截断
	--   "scroll" 随代码横滚 | "wrap" 总是折行
	-- 注意：只对 virt_lines 生效；placement = "eol"/"inline" 时无效。
	virt_lines_overflow = "auto",
	-- 不渲染的 server 名称黑名单，例如 { lua_ls = true }
	blacklist = {},
	-- 逐条过滤：fun(lens, client): boolean；返回 false 则丢弃该透镜。
	-- 默认 nil（全部渲染，包括 references / implementations / Run / Debug）。
	-- 想屏蔽某类时设成函数，例如：
	--   lens_filter = function(lens)
	--     local t = (lens.command and lens.command.title or ""):lower()
	--     return not t:find("implementation")
	--   end
	--@param lens table
	--@param client vim.lsp.Client
	lens_filter = nil,
	-- 悬停时对“字符本身”的强调（不画背景块）：会叠加到
	-- { fg = <主题 Special 的前景色>, bold = true } 上。
	-- 设为 false 则退回整块背景高亮（CodeLensHover link Visual）。
	hover_style = { bold = true },
	-- 隐藏「0 references / 0 implementations」这类零计数透镜。
	-- rust-analyzer 对没有任何引用的符号也会发一条，纯噪音，默认藏掉。
	hide_zero_lens = true,
	-- codeLens/resolve 的兜底超时（毫秒）。服务端不回收 resolve 请求时，
	-- 超时后就用已拿到的部分镜头渲染，而不是整次刷新静默丢结果。
	resolve_timeout = 3000,
	-- 每条透镜前面加一个 Nerd Font 图标，按类型区分：Run / Debug / 引用 / 实现 / 测试
	icons = true,
	-- 服务端标题自带图标时（rust-analyzer 的 "▶︎ Run" / "⚙︎ Debug" / "▶︎ Run Test"）
	-- 尊重它的原生效果：保留它的图标，我们不再叠加第二个图标。
	-- 设成 false 则一律剥掉服务端图标、统一用我们自己的。
	server_icons = true,
	-- 同一行有多个可执行透镜（如 Run + Debug + N references）时，用 vim.ui.select
	-- 弹选择器让用户选；设成 false 则直接跑第一个（视觉顺序从左到右）。
	pick_when_multiple = true,
	-- 图标配色（一）：从主题高亮组取前景色，换肤/换主题时自动跟着变。
	-- 某个 kind 设为 nil 表示不从主题取色，直接用下面的 icon_colors 兜底色。
	icon_color_groups = {
		run = "DiagnosticOk", -- 绿
		debug = "DiagnosticError", -- 红
		references = "Function", -- 蓝
		implementation = "Identifier", -- 紫
		test = "DiagnosticWarn", -- 黄
		generic = nil, -- 不走主题，用下面的金色
	},
	-- 图标配色（二）：兜底色 / 主题里没有对应诊断组时的回退色（OneDark 系）
	icon_colors = {
		run = "#98C379", -- 绿 : 可运行
		debug = "#E06C75", -- 红 : 可调试
		references = "#61AFEF", -- 蓝 : 引用
		implementation = "#56B6C2", -- 青 : 实现
		test = "#E5C07B", -- 铭黄 : 测试
		generic = "#FFD700", -- 金 : 其它
	},
}

---@return string
function M.placement()
	return M.config.placement or "above"
end

local ns = vim.api.nvim_create_namespace("lsp-config.codelens")

---@class CodeLensEntry
---@field client_id integer
---@field lens table

---@class CodeLensBufState
---@field clients integer[]
---@field lenses CodeLensEntry[]
---@field rows table<integer, CodeLensEntry[]>
---@field marks table<integer, integer>
---@field gen integer
---@field timer table|nil  -- vim.defer_fn 返回的 timer
---@field hover_row integer|nil
---@field hover_idx integer|nil

---@type table<integer, CodeLensBufState>
local bufs = {}

local render ---@type fun(bufnr: integer)  -- 前置声明（configure / ColorScheme 钩子要用）

---图标种类 → 高亮组名（CodeLensIconRun / CodeLensIconDebug / ...）
---@param kind string
---@return string
local function icon_hl(kind)
	return "CodeLensIcon" .. kind:sub(1, 1):upper() .. kind:sub(2)
end

---所有图标种类（同时也是 CodeLensIcon<Kind> 高亮组的白名单）
local ICON_KINDS = { "run", "debug", "references", "implementation", "test", "generic" }

local hl_ready = false
local function setup_highlights()
	if hl_ready then
		return
	end
	hl_ready = true
	vim.api.nvim_set_hl(0, "CodeLensTitle", { link = "LspCodeLens", default = true })
	vim.api.nvim_set_hl(0, "CodeLensSep", { link = "LspCodeLensSeparator", default = true })
	-- 没有 command 的透镜（点了也没反应）：灰掉，否则看起来能点却什么也不发生
	vim.api.nvim_set_hl(0, "CodeLensDisabled", { link = "Comment", default = true })
	-- 图标：每种类型一个高亮组，颜色优先取主题诊断色
	local groups = M.config.icon_color_groups or {}
	local colors = M.config.icon_colors or {}
	for _, kind in ipairs(ICON_KINDS) do
		local fg
		local group = groups[kind]
		if type(group) == "string" then
			-- link = false 让主题里 link 到别处的高亮组解析成真实颜色
			fg = (vim.api.nvim_get_hl(0, { name = group, link = false }) or {}).fg
		end
		fg = fg or colors[kind]
		if fg then
			-- bold：让 DiagnosticError 之类偏暗的主题色在小字号下也看得清
			vim.api.nvim_set_hl(0, icon_hl(kind), { fg = fg, bold = true, default = true })
		else
			vim.api.nvim_set_hl(0, icon_hl(kind), { link = "LspCodeLens", default = true })
		end
	end
	-- 兼容旧名字：CodeLensIcon 等价于 generic
	vim.api.nvim_set_hl(0, "CodeLensIcon", { link = icon_hl("generic"), default = true })
	local style = M.config.hover_style
	if style then
		-- 只强调字符本身：取主题 Special 的前景色 + 加粗，不设背景
		local fg = (vim.api.nvim_get_hl(0, { name = "Special" }) or {}).fg
		local opts = vim.tbl_extend("force", { fg = fg, bold = true }, style)
		opts.default = true
		vim.api.nvim_set_hl(0, "CodeLensHover", opts)
	else
		vim.api.nvim_set_hl(0, "CodeLensHover", { link = "Visual", default = true })
	end
end

---透镜虚拟文本的前导空格数：取该行行首空白字符的显示宽度（与 VSCode 一样按缩进对齐）
---@param bufnr integer
---@param entry CodeLensEntry
---@return integer
local function lens_indent(bufnr, entry)
	local ln = entry.lens.range.start.line
	local text = vim.api.nvim_buf_get_lines(bufnr, ln, ln + 1, false)[1] or ""
	return vim.fn.strdisplaywidth(text:match("^%s*") or "")
end

---服务端标题里自带的装饰性前缀，渲染前剥掉，否则会和我们的图标重复
---（rust-analyzer 发的是 "▶ Run" / "⚙ Debug" / "🧪 Test"，前面那个符号就是它自带的）
local DECOR_ASCII = {
	[0x20] = true, -- 空格
	[0x09] = true, -- tab
	[0x2A] = true, -- *
	[0x3E] = true, -- >
	[0x7C] = true, -- |
	[0x7E] = true, -- ~
}

---剥掉标题开头的装饰字符（ASCII 装饰 + U+2000 以上的符号/emoji 区，含变体选择符 U+FE0F）
---@param title string
---@return string
local function strip_decoration(title)
	local cps = vim.fn.str2list(title)
	local drop = 0
	for _, cp in ipairs(cps) do
		if DECOR_ASCII[cp] or (cp >= 0x2000 and cp <= 0x1FAFF) then
			drop = drop + 1
		else
			break
		end
	end
	if drop == 0 or drop == #cps then
		return title
	end
	return title:sub(vim.str_byteindex(title, drop) + 1)
end

---服务端原始标题（同时接受 CodeLensEntry 和裸 lens 表）
---@param entry CodeLensEntry|table
---@return string
local function raw_title(entry)
	local lens = entry.lens or entry
	return (lens.command and lens.command.title) or ""
end

---服务端标题是否自带图标（标题开头就是装饰字符）
---@param entry CodeLensEntry
---@return boolean
local function server_icon(entry)
	local raw = raw_title(entry)
	return strip_decoration(raw) ~= raw
end

---是否是「保留服务端图标」的情况（决定要不要配我们自己的图标）
---@param entry CodeLensEntry
---@return boolean
local function keep_server_icon(entry)
	return M.config.server_icons ~= false and server_icon(entry)
end

---渲染用标题：服务端自带图标的原样保留（尊重原生效果），否则剥掉装饰字符
---@param entry CodeLensEntry
---@return string
local function lens_title(entry)
	local raw = raw_title(entry)
	if keep_server_icon(entry) then
		return raw
	end
	return strip_decoration(raw)
end

---透镜是否可执行：command 表存在且 command 字段是非空字符串
---（有的 server 会给出 command = { title = ... } 这种空命令，直接送进
--- Client:exec_cmd 会报 "does not support command ``"）
---@param lens table
---@return boolean
local function is_executable(lens)
	local cmd = lens and lens.command
	return type(cmd) == "table" and type(cmd.command) == "string" and cmd.command ~= ""
end

---图标（Nerd Font）：kind → 字形。想换图标改这里即可
local LENS_ICONS = {
	run = "\u{f04b}", --  (play)
	debug = " ", --  (bug)
	references = " ", --  (link)
	implementation = " ", --  (sitemap)
	test = "󰙨", --  (flask)
	generic = "\u{f02d}", --  (generic)
}

---按透镜类型分类。
---规则：**标题关键词优先，命令名兜底**——因为同一个命令可能服务多种透镜
---（rust-analyzer 的「N references」和「N implementations」都发
---`rust-analyzer.showReferences`，只能靠标题区分，implementation 必须排最前），
---而别的 server 可能复用自己的命令名、标题里只有 "References (3)" 之类，
---这时靠命令名兜底分类，不会掉进 generic。
---@param entry CodeLensEntry
---@return string kind
local function lens_kind(entry)
	local title = strip_decoration(raw_title(entry)):lower()
	local cmd = (entry.lens.command or {}).command
	cmd = type(cmd) == "string" and cmd or ""
	-- 先看标题（标题是用户直接看到的语义），再看命令名兜底
	if title:find("implementation") then
		return "implementation"
	elseif title:find("reference") then
		return "references"
	elseif title:find("test") then
		return "test"
	elseif title:find("run") then
		return "run"
	elseif title:find("debug") then
		return "debug"
	elseif cmd:find("showReferences") then
		return "references"
	elseif cmd:find("runSingle") or cmd:find("runInTerminal") or cmd:find("run_tests") then
		return "run"
	elseif cmd:find("debugSingle") or cmd:find("startDebugging") then
		return "debug"
	end
	return "generic"
end

---按透镜类型取图标
---@param entry CodeLensEntry
---@return string glyph 图标 + 空格；不用图标时为 ""
---@return string? hl 图标高亮组
local function lens_icon(entry)
	-- 服务端标题里已经有图标（▶︎ Run / ⚙︎ Debug）→ 用它自己的，不再叠加
	if M.config.icons == false or keep_server_icon(entry) then
		return "", nil
	end
	local kind = lens_kind(entry)
	return LENS_ICONS[kind] .. " ", icon_hl(kind)
end

---透镜在屏幕上占的显示宽度（图标 + 标题），用于鼠标命中检测
---@param entry CodeLensEntry
---@return integer
local function entry_width(entry)
	local glyph = lens_icon(entry)
	return math.max(vim.fn.strdisplaywidth(glyph .. lens_title(entry)), 1)
end

---零计数透镜（"0 references" / "0 implementations"）：rust-analyzer 会给
---没有任何引用的符号也发一条，默认隐藏，避免满屏 "0 references"
---@param entry CodeLensEntry
---@return boolean
local function is_zero_lens(entry)
	if not M.config.hide_zero_lens then
		return false
	end
	return lens_title(entry):match("^%s*0%s") ~= nil
end

---逐条过滤：默认全部保留
---@param lens table
---@param client vim.lsp.Client
---@return boolean
local function passes_filter(lens, client)
	local f = M.config.lens_filter
	if not f then
		return true
	end
	local ok, keep = pcall(f, lens, client)
	return ok and keep ~= false
end

---构建一行的 virt_text（空格 + title1 + " | " + title2 ...），hover_idx 对应项使用高亮组
---@param bufnr integer
---@param entries CodeLensEntry[]
---@param hover_idx integer|nil
---@param placement string
---@return string|table[][] chunks
local function build_chunks(bufnr, entries, hover_idx, placement)
	local chunks
	if placement == "inline" then
		chunks = {}
	elseif placement == "eol" then
		chunks = { { "  ", "CodeLensSep" } }
	else
		chunks = { { string.rep(" ", lens_indent(bufnr, entries[1])), "CodeLensSep" } }
	end
	for i, e in ipairs(entries) do
		if i > 1 then
			chunks[#chunks + 1] = { "  ", "CodeLensSep" }
		end
		local glyph, glyph_hl = lens_icon(e)
		if glyph ~= "" then
			chunks[#chunks + 1] = { glyph, glyph_hl }
		end
		local hl
		if i == hover_idx then
			hl = "CodeLensHover"
		elseif is_executable(e.lens) then
			hl = "CodeLensTitle"
		else
			hl = "CodeLensDisabled"
		end
		chunks[#chunks + 1] = { lens_title(e), hl }
	end
	if placement == "inline" then
		chunks[#chunks + 1] = { "  ", "CodeLensSep" }
	end
	return chunks
end

---只重绘某一行（用于悬停切换，避免全量重绘闪烁）
---@param bufnr integer
---@param row integer 0-based
local function render_row(bufnr, row)
	local st = bufs[bufnr]
	if not st or not st.rows or not st.rows[row] then
		return
	end
	local entries = st.rows[row]
	local hover_idx = (st.hover_row == row) and st.hover_idx or nil
	local placement = M.placement()

	if st.marks[row] then
		pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, st.marks[row])
		st.marks[row] = nil
	end
	local chunks = build_chunks(bufnr, entries, hover_idx, placement)
	local opts
	if placement == "inline" then
		opts = { virt_text = chunks, virt_text_pos = "inline" }
	elseif placement == "eol" then
		opts = { virt_text = chunks, virt_text_pos = "eol" }
	else
		opts = {
			virt_lines = { chunks },
			virt_lines_above = (placement == "above"),
			virt_lines_overflow = M.config.virt_lines_overflow or "trunc",
		}
	end
	local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, opts)
	if ok then
		st.marks[row] = id
	end
end

---全量重绘
---@param bufnr integer
render = function(bufnr)
	local st = bufs[bufnr]
	if not st or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	st.marks = {}
	-- 行号可能因编辑而移动，旧的悬停状态（行/序号）已不可用，必须清掉
	st.hover_row, st.hover_idx = nil, nil

	local placement = M.placement()
	local rows = {}
	for _, e in ipairs(st.lenses) do
		local l = e.lens
		if l and l.range and l.range.start and lens_title(e) ~= "" and not is_zero_lens(e) then
			-- below：锚在 range 结束行（函数结束后）；其余锚在起始行
			local row = (placement == "below" and l.range["end"] and l.range["end"].line) or l.range.start.line
			rows[row] = rows[row] or {}
			rows[row][#rows[row] + 1] = e
		end
	end
	st.rows = rows
	for row in pairs(rows) do
		render_row(bufnr, row)
	end
end

---解析未带 command 的透镜
---@param client vim.lsp.Client
---@param bufnr integer
---@param lens table
---@param cb fun(resolved: table)
local function resolve_lens(client, bufnr, lens, cb)
	if lens.command then
		return cb(lens)
	end
	client:request("codeLens/resolve", lens, function(_, resolved)
		cb(resolved or lens)
	end, bufnr)
end

---释放一个 vim.defer_fn / uv timer
---@param t table?
local function kill_timer(t)
	if t then
		pcall(t.stop, t)
		pcall(t.close, t)
	end
end

---向所有已注册 client 请求透镜并渲染
---两处兜底，避免「服务端不回」导致整次刷新静默丢弃：
---  1. resolve 超时：codeLens/resolve 不回调时，到点用已拿到的部分渲染
---  2. 请求超时：textDocument/codeLens 完全不回时，到点结清剩余计数
---@param bufnr integer
---@param gen integer
local function request(bufnr, gen)
	local st = bufs[bufnr]
	if not st or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local clients = {}
	for _, id in ipairs(st.clients) do
		local c = vim.lsp.get_client_by_id(id)
		if c and not M.config.blacklist[c.name] then
			clients[#clients + 1] = c
		end
	end
	if #clients == 0 then
		st.lenses = {}
		render(bufnr)
		return
	end

	local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
	local timeout = M.config.resolve_timeout or 3000
	local acc = {}
	local pending = #clients
	local outer_timer

	local function client_done()
		pending = pending - 1
		if pending > 0 then
			return
		end
		kill_timer(outer_timer)
		outer_timer = nil
		local s = bufs[bufnr]
		if not s or s.gen ~= gen or not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		table.sort(acc, function(a, b)
			local ra, rb = a.lens.range.start, b.lens.range.start
			if ra.line ~= rb.line then
				return ra.line < rb.line
			end
			return (ra.character or 0) < (rb.character or 0)
		end)
		s.lenses = acc
		render(bufnr)
	end

	-- 兜底：整轮请求超时后把还没回音的 client 全部结清（各自只结一次）
	outer_timer = vim.defer_fn(function()
		local left = pending
		for _ = 1, left do
			client_done()
		end
	end, timeout)

	for _, client in ipairs(clients) do
		client:request("textDocument/codeLens", params, function(err, result)
			if err or type(result) ~= "table" or #result == 0 then
				return client_done()
			end
			local n = #result
			local done = 0
			local settled = false
			local resolve_timer
			local function settle()
				if settled then
					return
				end
				settled = true
				kill_timer(resolve_timer)
				resolve_timer = nil
				client_done()
			end
			resolve_timer = vim.defer_fn(settle, timeout)
			for _, lens in ipairs(result) do
				resolve_lens(client, bufnr, lens, function(resolved)
					if settled then
						return
					end
					if resolved and resolved.range and passes_filter(resolved, client) then
						acc[#acc + 1] = { client_id = client.id, lens = resolved }
					end
					done = done + 1
					if done == n then
						settle()
					end
				end)
			end
		end, bufnr)
	end
end

---停掉并释放挂起的防抖 timer
---@param st CodeLensBufState?
local function stop_timer(st)
	if st and st.timer then
		pcall(st.timer.stop, st.timer)
		pcall(st.timer.close, st.timer)
		st.timer = nil
	end
end

---立即刷新
---@param bufnr integer
function M.refresh(bufnr)
	bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
	local st = bufs[bufnr]
	if not st then
		return
	end
	stop_timer(st)
	st.gen = st.gen + 1
	request(bufnr, st.gen)
end

---防抖刷新
---@param bufnr integer
function M.schedule_refresh(bufnr)
	bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
	local st = bufs[bufnr]
	if not st then
		return
	end
	stop_timer(st)
	st.timer = vim.defer_fn(function()
		if bufs[bufnr] then
			bufs[bufnr].timer = nil
			M.refresh(bufnr)
		end
	end, 500)
end

---鼠标处命中的透镜
---@return integer|nil row 0-based
---@return integer|nil idx 同一行内的序号
---@return CodeLensEntry|nil entry
local function mouse_lens()
	local bufnr = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local st = bufs[bufnr]
	if not st or not st.rows then
		return nil
	end
	local mouse = vim.fn.getmousepos()
	if not mouse or not mouse.line or mouse.line < 1 then
		return nil
	end
	local wi = vim.fn.getwininfo(win)[1]
	local decol = mouse.wincol - ((wi and wi.textoff) or 0) -- 1-based 显示列
	local placement = M.placement()
	-- 横滚偏移对所有锚点行都一样，循环外取一次
	local leftcol = vim.fn.winsaveview().leftcol or 0

	-- 虚拟行归属于相邻的 buffer 行，所以鼠标所在行的锚点只可能在附近：
	-- 只检查 anchor ∈ {line-2, line-1, line}，避免每次鼠标移动都遍历全部透镜。
	local anchors = { mouse.line, mouse.line - 1, mouse.line - 2 }
	for _, anchor in ipairs(anchors) do
		local entries = st.rows[anchor]
		local sp = entries and vim.fn.screenpos(win, anchor + 1, 1)
		if sp and sp.row and sp.row > 0 then
			-- above：透镜画在锚点行上方一屏行；below：下方一屏行；eol/inline：同一屏行
			local hit
			if placement == "above" then
				hit = mouse.screenrow == sp.row - 1 and mouse.line == anchor + 1
			elseif placement == "below" then
				hit = mouse.screenrow == sp.row + 1 and mouse.line == anchor + 1
			else
				hit = mouse.screenrow == sp.row and mouse.line == anchor + 1
			end
			if hit then
				local col
				if placement == "eol" then
					local text = vim.api.nvim_buf_get_lines(bufnr, anchor, anchor + 1, false)[1] or ""
					col = vim.fn.strdisplaywidth(text) + 2 -- 行尾前缀 "  "
				elseif placement == "inline" then
					-- 内联虚拟文本渲染在行首，随横滚移动
					col = -leftcol
				else
					col = lens_indent(bufnr, entries[1])
					-- overflow = "scroll" 时虚拟行随代码横滚；"trunc" 时固定在文本区左侧
					if M.config.virt_lines_overflow == "scroll" then
						col = col - leftcol
					end
				end
				for i, e in ipairs(entries) do
					local width = entry_width(e)
					if decol >= col + 1 and decol <= col + width then
						return anchor, i, e
					end
					col = col + width + 3 -- " | "
				end
			end
		end
	end
	return nil
end

---@private 供测试用
M._lens_icon = lens_icon
M._lens_title = lens_title
M._lens_kind = lens_kind
M._bufs = bufs

---执行透镜命令。
---大多数 server 会在 `workspace/executeCommand` 里自己处理；但有一部分（clangd 的
---`clangd.showLocations`、gopls 的 `gopls.run_tests` 等）要求**客户端**处理，
---Neovim 会把它们转发给 server 然后什么都不发生。这里做一个通用兜底：
---语言后端没注册 handler、而参数里能挖出位置列表时，本地直接展示（跳转 / quickfix）。
---真正写好了自己的语义的后端（runnables/<lang>.lua）优先级更高。
---@param client vim.lsp.Client
---@param command table
---@param bufnr integer
local function exec_lens(client, command, bufnr)
	local name = command and command.command
	if type(name) == "string" and name ~= "" and not vim.lsp.commands[name] then
		local ok, handled = pcall(function()
			return require("lsp-config.features.runnables.locations").show_from_args(command.arguments)
		end)
		if ok and handled then
			return
		end
	end
	client:exec_cmd(command, { bufnr = bufnr })
end
M._exec_lens = exec_lens

---<MouseMove>：更新悬停高亮
function M.mousemove()
	local bufnr = vim.api.nvim_get_current_buf()
	local st = bufs[bufnr]
	if not st or not st.rows then
		return
	end
	local row, idx = mouse_lens()
	if row == st.hover_row and idx == st.hover_idx then
		return
	end
	local prev_row = st.hover_row
	st.hover_row, st.hover_idx = row, idx
	if prev_row and st.rows[prev_row] then
		render_row(bufnr, prev_row)
	end
	if row and st.rows[row] then
		render_row(bufnr, row)
	end
end

---<LeftMouse>：点在透镜上则执行，返回是否已处理
---@return boolean
function M.click()
	local bufnr = vim.api.nvim_get_current_buf()
	local st = bufs[bufnr]
	if not st then
		return false
	end
	local _, _, entry = mouse_lens()
	if not entry then
		return false
	end
	local command = entry.lens.command
	if vim.lsp.get_client_by_id(entry.client_id) and is_executable(entry.lens) then
		-- 点击来自 expr 映射，此处处于 textlock，直接执行会触发
		-- E565（not allowed to change text or window），故调度到安全上下文。
		vim.schedule(function()
			local c = vim.lsp.get_client_by_id(entry.client_id)
			if c then
				exec_lens(c, command, bufnr)
			end
		end)
	end
	return true
end

---执行光标所在行的透镜（above 布局下也包括声明行下一行的那条）
---@return boolean handled 是否真的执行了某条透镜
function M.run_at_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local st = bufs[bufnr]
	if not st or not st.rows then
		return false
	end
	local line = vim.api.nvim_win_get_cursor(0)[1] -- 1-based 光标行
	-- above：透镜画在声明行上方一屏行，光标停在那条虚拟行时落在上一行 buffer 行上
	local rows = { line - 1 }
	if M.placement() == "above" then
		rows[#rows + 1] = line
	end
	-- 收集该行所有可执行透镜（按视觉顺序）。常见情况：一个紧声明上同时挂着
	-- `▶︎ Run` / `⚙︎ Debug` / `N references`，必须让用户选，不能默默跑第一个。
	local cands = {}
	local seen = {}
	for _, row in ipairs(rows) do
		for _, e in ipairs(st.rows[row] or {}) do
			local c = is_executable(e.lens) and vim.lsp.get_client_by_id(e.client_id)
			if c and not seen[e.lens] and not is_zero_lens(e) then
				seen[e.lens] = true
				cands[#cands + 1] = { client = c, lens = e.lens }
			end
		end
	end
	if #cands == 0 then
		return false
	end
	local function exec(pick)
		exec_lens(pick.client, pick.lens.command, bufnr)
	end
	if #cands == 1 or M.config.pick_when_multiple == false then
		exec(cands[1])
		return true
	end
	-- 多个：列成选项（标题重复时补序号，避免看不出区别）
	local counts, label_of = {}, {}
	for _, p in ipairs(cands) do
		local t = lens_title(p.lens)
		counts[t] = (counts[t] or 0) + 1
	end
	local seen_label = {}
	for _, p in ipairs(cands) do
		local t = lens_title(p.lens)
		if counts[t] > 1 then
			seen_label[t] = (seen_label[t] or 0) + 1
			t = string.format("%s (%d)", t, seen_label[t])
		end
		label_of[p] = t
	end
	vim.ui.select(cands, {
		prompt = "Code lens",
		format_item = function(item)
			return label_of[item] or lens_title(item.lens)
		end,
	}, function(pick)
		if pick then
			exec(pick)
		end
	end)
	return true
end

local detach_installed = false
local function install_detach()
	if detach_installed then
		return
	end
	detach_installed = true
	vim.api.nvim_create_autocmd("LspDetach", {
		group = vim.api.nvim_create_augroup("LspCodeLensDetach", { clear = true }),
		callback = function(args)
			local st = bufs[args.buf]
			if not st then
				return
			end
			local removed = false
			for i = #st.clients, 1, -1 do
				if st.clients[i] == args.data.client_id then
					table.remove(st.clients, i)
					removed = true
				end
			end
			if removed then
				M.refresh(args.buf)
			end
		end,
	})
end

---换肤后主题派生的图标色会失效：重置缓存、重建高亮、重绘
local colorscheme_installed = false
local function install_colorscheme_hook()
	if colorscheme_installed then
		return
	end
	colorscheme_installed = true
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("LspCodeLensColors", { clear = true }),
		callback = function()
			hl_ready = false
			setup_highlights()
			for bufnr in pairs(bufs) do
				if vim.api.nvim_buf_is_valid(bufnr) then
					render(bufnr)
				end
			end
		end,
	})
end

local refresh_installed = false
local function install_server_refresh()
	if refresh_installed then
		return
	end
	refresh_installed = true
	local orig = vim.lsp.handlers["workspace/codeLens/refresh"]
	vim.lsp.handlers["workspace/codeLens/refresh"] = function(err, result, ctx, config)
		local cid = ctx and ctx.client_id
		for bufnr, st in pairs(bufs) do
			-- 只刷真正挂了该 client 的 buffer（跨 server 的广播不必全体重算）
			if vim.api.nvim_buf_is_valid(bufnr) and (not cid or vim.tbl_contains(st.clients, cid)) then
				M.refresh(bufnr)
			end
		end
		if orig then
			return orig(err, result, ctx, config)
		end
		return vim.NIL
	end
end

-- 观察（不消费）鼠标事件。
-- 注意：不能用 buffer-local 的 <MouseMove>/<LeftMouse> 映射：它会遮蔽 bufferline.nvim
-- 等注册的全局 <MouseMove> 映射，且 expr 映射会吞掉普通 <LeftMouse>（返回 termcode 的
-- 透传对鼠标不可靠），导致单击无法定位光标。vim.on_key 只观察、不拦截。
local mousemove_key = vim.api.nvim_replace_termcodes("<MouseMove>", true, false, true)
local leftmouse_key = vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true)
local observer_installed = false
local function install_mousemove_observer()
	if observer_installed then
		return
	end
	observer_installed = true
	vim.on_key(function(key)
		if key == mousemove_key then
			pcall(M.mousemove)
		elseif key == leftmouse_key then
			pcall(M.click)
		end
	end, ns)
end

---@param client vim.lsp.Client
---@param bufnr integer
function M.setup(client, bufnr)
	if not (client.server_capabilities and client.server_capabilities.codeLensProvider) then
		return
	end
	if M.config.blacklist[client.name] then
		return
	end
	setup_highlights()
	install_colorscheme_hook()
	install_detach()
	install_server_refresh()

	if not bufs[bufnr] then
		bufs[bufnr] = { clients = {}, lenses = {}, rows = {}, marks = {}, gen = 0 }

		local grp = vim.api.nvim_create_augroup("LspCodeLens" .. bufnr, { clear = true })
		-- 只在「停下来」的时机刷新：InsertLeave / BufWritePost。
		-- 不再监听 TextChanged：normal-mode 每次 x/p/dd/u 都会重新跑一轮
		-- codeLens + codeLens/resolve（实测 ~12ms rust-analyzer CPU），而 references
		-- 数字在两次停下之间几乎不变，视觉上看不出区别。
		vim.api.nvim_create_autocmd({ "InsertLeave", "BufWritePost" }, {
			group = grp,
			buffer = bufnr,
			callback = function()
				M.schedule_refresh(bufnr)
			end,
		})
		vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
			group = grp,
			buffer = bufnr,
			callback = function()
				stop_timer(bufs[bufnr])
				bufs[bufnr] = nil
			end,
		})

		-- 悬停高亮需要鼠标移动事件
		vim.o.mousemoveevent = true
		-- 鼠标事件通过 vim.on_key 观察（见 install_mousemove_observer），不安装
		-- <LeftMouse>/<MouseMove> 映射：映射会吞掉/遮蔽普通点击与其他插件的映射。
		install_mousemove_observer()
	end

	local st = bufs[bufnr]
	if not vim.tbl_contains(st.clients, client.id) then
		st.clients[#st.clients + 1] = client.id
	end
	M.refresh(bufnr)
end

---覆盖配置（与当前值合并）
---@param opts table
function M.configure(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	hl_ready = false
	setup_highlights()
	for bufnr in pairs(bufs) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			M.refresh(bufnr)
		end
	end
end

return M
