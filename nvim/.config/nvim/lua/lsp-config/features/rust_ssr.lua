-- lua/lsp-config/features/rust_ssr.lua
-- rust-analyzer 结构化搜索替换（experimental/ssr）
--
-- 与 grug-far（ripgrep / ast-grep）的分工：SSR 是「语义」替换——匹配走 rust-analyzer 的
-- 路径/类型解析，所以 `String::from($x)` 既能命中 `String::from(s)`，也能命中写法等价但
-- 文本不同的形式（UFCS ↔ 方法调用）；占位符在模板里位置变化时会自动补 `*` / `&` / `&mut`。
-- 代价：只有 Rust；而且服务端**没有 dry-run**（parseOnly = true 时返回空 edits），
-- 所以这里自己补一层预览：
--   1) 两栏输入（Search / Replace）→ 拼成 `search ==>> replace`
--   2) 请求返回 WorkspaceEdit（此时还没有任何 buffer 被改）
--   3) core.float-list 列出「文件:行 旧 ⟹ 新」，<CR> 跳过去看上下文，a 才应用，
--      d 用 codediff 打开「现在 vs 应用后」的单文件 diff（生成在 cache 里的临时副本）
--
-- UI 复用：
--   输入 → dap-extensions.ui.popup（两栏 + 历史；未加载时退回 vim.ui.input）
--   预览 → core.float-list（j/k、<CR>、a、d、?、q 都由它提供）
--   diff → codediff.nvim 的 file_diff handler（两个磁盘路径对比，inline 布局跟着用户配置）
--
-- 用法（在 LspAttach 中调用 setup）：
--   :RustSsr           弹输入框（两栏）
--   :RustSsr <query>   直接给完整 query（语法 `搜索 ==>> 替换`）
--   :RustSsr! ...      跳过预览，直接应用
--   :RustSsrApply      应用上一次预览的结果（预览被 <CR> 跳走后仍可用）
--   普通模式  grS = 整个 workspace    grs = 光标所在行（限制范围）
--   可视模式  grS / grs = 选区
--
-- 注意事项：
--   - workspace 范围是整个项目（所有 crate/member），一次确认可能改几十上百个文件，
--     动手前先 commit，或者先用 grs 把范围收窄。
--   - 撤销是「逐 buffer」的 u（一次 apply 会产生很多 buffer 的修改），不是全局一次性撤销。
--   - pending 只保留最近一份，再次请求会覆盖它。
--   - d 的 diff 里「修改侧」是 ~/.cache/nvim/ssr-preview/<hash>/<文件名> 的临时副本，
--     在 diff 里编辑不会影响真实文件；改完 `rm -rf ~/.cache/nvim/ssr-preview` 即可。
--   - 预览后到 apply 之前尽量不要改动那些文件，否则 WorkspaceEdit 携带的版本号会过期。

local M = {}

local float_list = require("core.float-list")

---@class RustSsrPending
---@field edit table WorkspaceEdit
---@field encoding string
---@field query string
---@field count integer

--- 最近一次请求结果（WorkspaceEdit 只对当前会话有意义，不需要按 buffer 隔离）
---@type RustSsrPending|nil
local pending = nil

local function notify(msg, level)
	vim.notify("[SSR] " .. msg, level or vim.log.levels.INFO)
end

--- 单行显示用截断
---@param s string
---@param max integer
---@return string
local function clip(s, max)
	if s == "" then
		return "∅"
	end
	if vim.fn.strdisplaywidth(s) <= max then
		return s
	end
	return vim.fn.strcharpart(s, 0, max) .. "…"
end

--- 取文件内容：优先用已加载的 buffer（可能有未写盘的修改），否则读磁盘
---@param uri string
---@return string[]
local function read_lines(uri)
	local ok, buf = pcall(vim.uri_to_bufnr, uri)
	if ok and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
		return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	end
	local ok2, lines = pcall(vim.fn.readfile, vim.uri_to_fname(uri))
	return ok2 and lines or {}
end

--- WorkspaceEdit → { [uri] = TextEdit[] }（兼容 changes 与 documentChanges）
---@param edit table
---@return table<string, table[]>
local function normalize_changes(edit)
	local changes = {}
	local function add(uri, edits)
		local list = changes[uri] or {}
		vim.list_extend(list, edits or {})
		changes[uri] = list
	end
	for _, dc in ipairs(edit.documentChanges or {}) do
		-- SSR 只产生 TextDocumentEdit；Create/Rename/DeleteFile 没有 textDocument 字段
		if dc.textDocument then
			add(dc.textDocument.uri, dc.edits)
		end
	end
	for uri, edits in pairs(edit.changes or {}) do
		add(uri, edits)
	end
	return changes
end

--- 把 WorkspaceEdit 摊平成列表条目（range 是修改前坐标，旧文本直接从当前内容取）
---@param edit table
---@return table[] items, integer count
local function build_items(edit)
	local changes = normalize_changes(edit)
	local items, count = {}, 0
	for uri, edits in pairs(changes) do
		if #edits > 0 then
			local fname = vim.uri_to_fname(uri)
			local lines = read_lines(uri)
			for _, e in ipairs(edits) do
				count = count + 1
				local lnum = e.range.start.line + 1
				local new_lines = vim.split(e.newText, "\n", { plain = true })
				table.insert(items, {
					uri = uri,
					file = fname,
					lnum = lnum,
					col = e.range.start.character + 1, -- 预览跳转用，utf-16 列号只当近似值
					old = lines[lnum] or "",
					new = new_lines[1] or "",
					multiline = #new_lines > 1 or e.range["end"].line ~= e.range.start.line,
				})
			end
		end
	end
	table.sort(items, function(a, b)
		if a.file ~= b.file then
			return a.file < b.file
		end
		return a.lnum < b.lnum
	end)
	return items, count
end

--- 相对当前目录的短路径
---@param file string
---@return string
local function short_path(file)
	return vim.fn.fnamemodify(file, ":.")
end

--- 列表行文本（同时用于高亮偏移计算）
---@param it table
---@return string prefix, string old, string new, string suffix
local function item_parts(it)
	local prefix = ("%s:%d  "):format(short_path(it.file), it.lnum)
	return prefix, clip(it.old, 60), clip(it.new, 60), it.multiline and "  (多行/整块)" or ""
end

--- 完整的单行文本
---@param it table
---@return string
local function item_text(it)
	local prefix, old, new, suffix = item_parts(it)
	return prefix .. old .. " ⟹ " .. new .. suffix
end

--- 跳到命中处看上下文
---@param it table
local function jump(it)
	vim.schedule(function()
		local ok, err = pcall(vim.cmd, "edit " .. vim.fn.fnameescape(it.file))
		if not ok then
			notify("打开失败：" .. tostring(err), vim.log.levels.ERROR)
			return
		end
		local line = vim.api.nvim_buf_get_lines(0, it.lnum - 1, it.lnum, false)[1] or ""
		local col = math.max(0, math.min(it.col - 1, #line))
		pcall(vim.api.nvim_win_set_cursor, 0, { it.lnum, col })
		pcall(vim.cmd, "normal! zv")
	end)
end

--- LSP 字符偏移 → 行内字节偏移（range 的 character 是 utf-16/utf-32 码元）
---@param line string
---@param off integer
---@param enc string
---@return integer
local function to_byte(line, off, enc)
	if enc ~= "utf-16" and enc ~= "utf-32" then
		return math.min(off, #line) -- utf-8
	end
	-- nvim 0.12+ API：(s, encoding, index, strict_indexing)；旧版：(s, index, use_utf16)
	-- strict=false：越界的 column 落在行尾而不是抛错（服务端偶尔给多一列）
	local ok, res = pcall(vim.str_byteindex, line, enc, off, false)
	if ok then
		return res
	end
	local ok2, res2 = pcall(vim.str_byteindex, line, off, enc == "utf-16")
	return (ok2 and res2) or #line
end

--- 把 TextEdit[] 应用到一份文本上（纯内存，不碰 buffer）
---@param lines string[]
---@param edits table[]
---@param enc string
---@return string[]
local function apply_text_edits(lines, edits, enc)
	local text = table.concat(lines, "\n")
	local line_start, pos = {}, 0
	for i, l in ipairs(lines) do
		line_start[i] = pos
		pos = pos + #l + 1
	end
	local function abs(p)
		local idx = p.line + 1
		local line = lines[idx] or ""
		return (line_start[idx] or #text) + to_byte(line, p.character, enc)
	end

	local ranges = {}
	for _, e in ipairs(edits) do
		ranges[#ranges + 1] = { abs(e.range.start), abs(e.range["end"]), e.newText }
	end
	-- 从后往前替换，前面的偏移就不会失效
	table.sort(ranges, function(a, b)
		return a[1] > b[1]
	end)
	for _, r in ipairs(ranges) do
		text = text:sub(1, r[1]) .. r[3] .. text:sub(r[2] + 1)
	end
	return vim.split(text, "\n", { plain = true })
end

--- 用 codediff 预览当前条目所在文件的改动（before = 现在的内容，after = 应用 SSR 之后）
---@param it table
local function open_diff(it)
	if not pending or not pending.changes then
		return
	end
	local edits = pending.changes[it.uri]
	if not edits or #edits == 0 then
		notify("这个文件没有待应用的修改", vim.log.levels.WARN)
		return
	end
	local ok_mod, file_diff = pcall(require, "codediff.commands.handlers.file_diff")
	if not (ok_mod and type(file_diff.run) == "function") then
		notify("codediff 不可用（检查 lua/plugins/codediff.lua 是否加载）", vim.log.levels.ERROR)
		return
	end

	local before = vim.uri_to_fname(it.uri)
	local dir = ("%s/ssr-preview/%s"):format(vim.fn.stdpath("cache"), vim.fn.sha256(it.uri):sub(1, 8))
	local after = dir .. "/" .. vim.fn.fnamemodify(before, ":t")
	local ok, err = pcall(function()
		vim.fn.mkdir(dir, "p")
		vim.fn.writefile(apply_text_edits(read_lines(it.uri), edits, pending.encoding), after)
	end)
	if not ok then
		notify("生成 diff 预览失败：" .. tostring(err), vim.log.levels.ERROR)
		return
	end

	local ok2, err2 = pcall(file_diff.run, before, after, { exit_on_close = false })
	if not ok2 then
		notify("codediff 打开失败：" .. tostring(err2), vim.log.levels.ERROR)
		return
	end
	notify(("%d 处改动预览（SSR 结果仍保留：:RustSsrApply 应用 / ! 应用到已写盘内容）"):format(#edits))
end

--- 当前打开的预览列表（重复预览时先关旧的，避免叠窗）
---@type table|nil
local active_list = nil

--- 应用 pending 的 WorkspaceEdit
local function apply_pending()
	if not pending then
		notify("没有待应用的 SSR 结果", vim.log.levels.WARN)
		return false
	end
	local ok, err = pcall(vim.lsp.util.apply_workspace_edit, pending.edit, pending.encoding)
	if not ok then
		notify("应用失败（文件可能已被改动，请重新执行 SSR）：" .. tostring(err), vim.log.levels.ERROR)
		return false
	end
	notify(("已应用 %d 处修改：%s（逐 buffer u 撤销，:wa 写盘）"):format(pending.count, pending.query))
	pending = nil
	return true
end

--- 打开结果预览列表
---@param items table[]
---@param query string
local function open_preview(items, query)
	local files, seen = 0, {}
	for _, it in ipairs(items) do
		if not seen[it.file] then
			seen[it.file] = true
			files = files + 1
		end
	end

	---@type table
	local list = float_list.new({
		title = (" SSR: %s "):format(clip(query, 48)),
		width = function()
			local w = 40
			for _, it in ipairs(items) do
				w = math.max(w, vim.fn.strdisplaywidth(item_text(it)) + 4)
			end
			return w
		end,
		height = function(n)
			return n
		end,
		max_height = 22,
		number_keys = false,
		close_when_empty = false,
		rows = function()
			return items
		end,
		text = function(it)
			return item_text(it)
		end,
		highlights = function(it)
			local prefix, old, new, suffix = item_parts(it)
			local s1 = #prefix
			local s2 = s1 + #old
			local s3 = s2 + #" ⟹ "
			local s4 = s3 + #new
			return {
				{ "Comment", 0, s1 },
				{ "DiffDelete", s1, s2 },
				{ "NonText", s2, s3 },
				{ "DiffAdd", s3, s4 },
				{ "Comment", s4, s4 + #suffix },
			}
		end,
		enter = function(it, _, self)
			self:close("jump")
			jump(it)
		end,
		keymaps = {
			{
				"a",
				function(self)
					if apply_pending() then
						self:close("applied")
					end
				end,
			},
			{
				"d",
				function(self)
					local idx = self:current()
					local it = idx and self.items[idx]
					if not it then
						return
					end
					self:close("diff") -- 关列表但保留 pending，之后仍可 :RustSsrApply
					open_diff(it)
				end,
			},
			{
				"y",
				function(self)
					-- 注意：float-list 的 current() 返回的是下标（1-based），不是条目本身
					local idx = self:current()
					local it = idx and self.items[idx]
					if not it then
						return
					end
					vim.fn.setreg(vim.v.register ~= "" and vim.v.register or "\"", ("%s ==>> %s"):format(it.old, it.new))
					notify("已复制当前行的旧/新文本，可整理成 query 模板")
				end,
			},
		},
		help = {
			{ "<CR>", "跳到命中处看上下文（预览不关闭 pending）" },
			{ "a", "应用全部修改" },
			{ "d", "用 codediff 看当前文件会变成什么样（不应用）" },
			{ "j / k", "上下移动" },
			{ "y", "把当前行的旧/新文本拼成 query 复制" },
			{ "q / <Esc>", "取消（丢弃结果）" },
		},
		on_close = function(reason)
			if reason == "cancel" and pending then
				pending = nil
				notify("已取消，结果已丢弃")
			end
		end,
	})
	if active_list and active_list:is_open() then
		active_list:close("replaced")
	end
	active_list = list
	list:toggle()
	notify(("%d 处匹配 / %d 个文件：<CR> 跳转，a 应用，d 看 diff，q 取消"):format(#items, files))
end

--- 发请求（pos 是触发时抓的坐标，避免被输入浮窗改掉当前窗口）
---@param client vim.lsp.Client
---@param bufnr integer
---@param query string
---@param selections table[]|nil
---@param apply_now boolean
---@param pos { textDocument: table, position: table }
local function request(client, bufnr, query, selections, apply_now, pos)
	-- 服务端只认 `==>>` 这一个分隔符（其它写法会回 `Parse error: Cannot find delimiter`）
	if not query:find("==>>", 1, true) then
		notify("query 缺少分隔符，格式：`搜索 ==>> 替换`", vim.log.levels.WARN)
		return
	end

	local enc = client.offset_encoding or "utf-8"
	notify("请求中…（" .. ((selections and #selections > 0) and "选区/行范围" or "整个 workspace") .. "）")

	client:request("experimental/ssr", {
		textDocument = pos.textDocument,
		position = pos.position,
		query = query,
		parseOnly = false, -- parseOnly = true 时服务端返回空 edits，没法用于预览
		selections = selections or {},
	}, function(err, result)
		if err then
			notify("请求失败：" .. (err.message or tostring(err)), vim.log.levels.ERROR)
			return
		end
		if not result then
			notify("没有命中")
			return
		end

		local items, count = build_items(result)
		if count == 0 then
			notify("没有命中")
			return
		end

		pending = { edit = result, encoding = enc, query = query, count = count, changes = normalize_changes(result) }

		if apply_now then
			apply_pending()
			return
		end
		open_preview(items, query)
	end, bufnr)
end

--- 两栏输入（dap-extensions.ui.popup），不可用时退回 vim.ui.input
---@param on_query fun(query: string)
local function ask_query(on_query)
	local ok, popup = pcall(require, "dap-extensions.ui.popup")
	if ok and type(popup.open) == "function" then
		popup.open({
			fields = {
				{ key = "search", label = "Search" },
				{ key = "replace", label = "Replace" },
			},
			on_submit = function(r)
				local search, replace = r.search or "", r.replace or ""
				if search == "" then
					return
				end
				on_query(search .. " ==>> " .. replace)
			end,
		})
		return
	end
	vim.ui.input({ prompt = "SSR (搜索 ==>> 替换): " }, function(input)
		if input and input ~= "" then
			on_query(input)
		end
	end)
end

--- 触发一次 SSR（抓当前光标位置 → 询问 query → 请求）
---@param client vim.lsp.Client
---@param bufnr integer
---@param query string|nil 直接给定的完整 query
---@param selections table[]|nil
---@param apply_now boolean
local function trigger(client, bufnr, query, selections, apply_now)
	local enc = client.offset_encoding or "utf-8"
	-- 必须在弹输入浮窗之前抓坐标：浮窗会切换当前窗口/缓冲区
	local pos_params = vim.lsp.util.make_position_params(0, enc)
	local pos = { textDocument = pos_params.textDocument, position = pos_params.position }

	if query and query ~= "" then
		request(client, bufnr, query, selections, apply_now, pos)
		return
	end

	ask_query(function(q)
		request(client, bufnr, q, selections, apply_now, pos)
	end)
end

--- 光标所在整行的 Range（列不精确也没关系，仅用于收窄作用域）
---@return table
local function current_line_range()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	return {
		start = { line = row, character = 0 },
		["end"] = { line = row + 1, character = 0 },
	}
end

---@param client vim.lsp.Client
---@param bufnr integer
---@return table
local function visual_range(client)
	return vim.lsp.util.make_given_range_params(nil, nil, 0, client.offset_encoding or "utf-8").range
end

--- 安装到某个 LSP client / buffer
---@param client vim.lsp.Client
---@param bufnr integer
function M.setup(client, bufnr)
	if not client or client.name ~= "rust-analyzer" then
		return
	end
	if not client:supports_method("experimental/ssr", bufnr) then
		return
	end

	local key_opts = { buffer = bufnr, noremap = true, silent = true }

	vim.keymap.set("n", "grS", function()
		trigger(client, bufnr, nil, nil, false)
	end, vim.tbl_extend("force", key_opts, { desc = "SSR: 整个 workspace 结构化替换（先预览）" }))

	vim.keymap.set("x", "grS", function()
		trigger(client, bufnr, nil, { visual_range(client) }, false)
	end, vim.tbl_extend("force", key_opts, { desc = "SSR: 选区内结构化替换（先预览）" }))

	vim.keymap.set("n", "grs", function()
		trigger(client, bufnr, nil, { current_line_range() }, false)
	end, vim.tbl_extend("force", key_opts, { desc = "SSR: 光标行内结构化替换（先预览）" }))

	vim.keymap.set("x", "grs", function()
		trigger(client, bufnr, nil, { visual_range(client) }, false)
	end, vim.tbl_extend("force", key_opts, { desc = "SSR: 选区内结构化替换（先预览）" }))

	vim.api.nvim_buf_create_user_command(bufnr, "RustSsr", function(args)
		trigger(client, bufnr, args.args, nil, args.bang)
	end, { nargs = "*", bang = true, desc = "rust-analyzer 结构化搜索替换（! 跳过预览）" })

	vim.api.nvim_buf_create_user_command(bufnr, "RustSsrApply", function()
		apply_pending()
	end, { nargs = 0, desc = "应用上一次 :RustSsr 预览的结果" })
end

-- 导出内部函数供测试
M._pending = function()
	return pending
end
M._build_items = build_items
M._normalize_changes = normalize_changes
M._open_preview = open_preview

return M
