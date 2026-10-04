-- lua/lsp-config/features/utf8_guard.lua
--[[
LSP UTF-8 守卫（常驻探针 + 保护）
=================================

【为什么需要】
  rust-analyzer 等 LSP server 在收到「非法 UTF-8」的 JSON-RPC 报文时，不会优雅报错，
  而是直接在 `rust_analyzer::session::run_session` 里 anyhow 失败并退出：
      Error: client exited without proper shutdown sequence
      invalid utf-8 sequence of N bytes from index X
  Neovim 的 buffer 是字节数组，可以存非法 UTF-8（插件写入原始字节、二进制被误读进来等），
  而 didOpen / didChange / didSave 会把这段文本广播给所有 client —— server 就这么挂了。

【做了什么】
  分两层：

  1) 缓冲区层（从源头修复，主要防线）
     在 buffer 变更后就地扫描并替换非法字节为 U+FFFD，保证 buffer 自身是合法 UTF-8。
     这样所有 client / formatter / treesitter 看到的文本一致，服务端内部文档不会与 buffer 错位。
     详见下方「缓冲区修复」一节。

  2) 发送关口（兜底）
     在 client 上包一层 `notify` / `request`，发送前递归扫描 params 里的字符串：
       * 合法          -> 原样放过（走快路径，零拷贝、不改元表）
       * 发现非法字节  -> 对 didChange 改为「整篇文档替换」并发送当前 buffer 的合法全文
                          （避免增量 range 落在字符中间，rust-analyzer 会 panic
                            “start of range should be a character boundary”）；
                          其它 method 就地替换为 U+FFFD (EF BF BD)，并打印
                          client / method / uri / 首个坏字节偏移 / 十六进制片段
     即使缓冲区层因为某些原因漏掉了（例如 debounce=0 的同步 flush），这一层也能阻止 server 退出。

  为什么大部分情况用「就地替换」而不是 deepcopy 一份再改：
    1. params 里可能有 `vim.empty_dict()` 之类的元表，deepcopy 后会退化成普通 table，
       编码成 JSON 时会从 `{}` 变成 `[]`，反而破坏协议；
    2. didChange 的 contentChanges 可能很大，deepcopy 会有一次额外的内存/时间开销；
    3. 只在发现非法字节时才改写原始表，正常路径完全不触碰数据。
  （只有 didChange 发现非法字节时例外：整个 contentChanges 会被换成一个全量替换事件。）

【接入方式】
  缓冲区层（全局一次，见 lsp-config/autocmds.lua）：
      require("lsp-config.features.utf8_guard").setup_buffer_guard()
  发送关口（每个 client，LspAttach 中）：
      require("lsp-config.features.utf8_guard").setup(client)
]]

local M = {}

-- 只守卫这些 server 名；nil = 守卫全部。
-- LSP 协议本就要求 UTF-8，全部守卫更安全；若哪天某个 server 有特殊需求可在此收窄。
---@type string[]|nil
M.servers = nil

-- 递归深度上限，防止异常/自引用结构导致爆栈
local MAX_DEPTH = 16

-- 同一 client + method 的重复告警节流（毫秒），避免每敲一个字刷屏
local WARN_INTERVAL_MS = 1000
local last_warn = {}
-- 记录最近一次 buffer 修复时间（bufnr -> uv.now()），供发送关口避免重复告警
local buf_repaired_at = {}
-- 同一 contentChanges 表会被同一 sync group 的多个 client 共享（send_changes 里复用）。
-- 第一个 client 就地修好字符串后，后面的 client 扫不到脏数据，需要用这张表记忆。
local bad_changes = setmetatable({}, { __mode = "k" })

-- U+FFFD REPLACEMENT CHARACTER 的 UTF-8 字节
local REPLACEMENT = "\239\191\189"

--[[
按 UTF-8 规则逐字节校验，非法处替换为 U+FFFD。
  合法时返回 nil（快路径，不分配新字符串）；
  非法时返回 fixed_string, first_bad_offset(1-based), hex_preview。

实现遵循 UTF-8 的最短编码与代理区限制：
  - 2 字节：C2..DF + 80..BF
  - 3 字节：E0 A0..BF / E1..EC 80..BF / ED 80..9F（排除代理区）/ EE..EF 80..BF
  - 4 字节：F0 90..BF / F1..F3 80..BF / F4 80..8F（不超过 U+10FFFF）
  非法字节按「每个字节一个 U+FFFD」替换，保证输出必然是合法 UTF-8。
]]
---@param s string
---@return string|nil, integer|nil, string|nil
local function sanitize(s)
	local n = #s
	local i = 1
	local out = nil -- 惰性创建：只有真的发现非法才需要重拼
	local bad_at = nil
	local run_start = 1 -- 当前连续合法片段起点（成段 sub，避免逐字符 sub）

	while i <= n do
		local c = s:byte(i)
		local len = 0

		if c < 0x80 then
			len = 1
		elseif c >= 0xC2 and c <= 0xDF then
			local c2 = s:byte(i + 1)
			if c2 and c2 >= 0x80 and c2 <= 0xBF then
				len = 2
			end
		elseif c == 0xE0 then
			local c2, c3 = s:byte(i + 1), s:byte(i + 2)
			if c2 and c3 and c2 >= 0xA0 and c2 <= 0xBF and c3 >= 0x80 and c3 <= 0xBF then
				len = 3
			end
		elseif c >= 0xE1 and c <= 0xEC then
			local c2, c3 = s:byte(i + 1), s:byte(i + 2)
			if c2 and c3 and c2 >= 0x80 and c2 <= 0xBF and c3 >= 0x80 and c3 <= 0xBF then
				len = 3
			end
		elseif c == 0xED then
			-- ED A0..BF 是 UTF-16 代理区，非法
			local c2, c3 = s:byte(i + 1), s:byte(i + 2)
			if c2 and c3 and c2 >= 0x80 and c2 <= 0x9F and c3 >= 0x80 and c3 <= 0xBF then
				len = 3
			end
		elseif c >= 0xEE and c <= 0xEF then
			local c2, c3 = s:byte(i + 1), s:byte(i + 2)
			if c2 and c3 and c2 >= 0x80 and c2 <= 0xBF and c3 >= 0x80 and c3 <= 0xBF then
				len = 3
			end
		elseif c == 0xF0 then
			local c2, c3, c4 = s:byte(i + 1), s:byte(i + 2), s:byte(i + 3)
			if
				c2
				and c3
				and c4
				and c2 >= 0x90
				and c2 <= 0xBF
				and c3 >= 0x80
				and c3 <= 0xBF
				and c4 >= 0x80
				and c4 <= 0xBF
			then
				len = 4
			end
		elseif c >= 0xF1 and c <= 0xF3 then
			local c2, c3, c4 = s:byte(i + 1), s:byte(i + 2), s:byte(i + 3)
			if
				c2
				and c3
				and c4
				and c2 >= 0x80
				and c2 <= 0xBF
				and c3 >= 0x80
				and c3 <= 0xBF
				and c4 >= 0x80
				and c4 <= 0xBF
			then
				len = 4
			end
		elseif c == 0xF4 then
			local c2, c3, c4 = s:byte(i + 1), s:byte(i + 2), s:byte(i + 3)
			if
				c2
				and c3
				and c4
				and c2 >= 0x80
				and c2 <= 0x8F
				and c3 >= 0x80
				and c3 <= 0xBF
				and c4 >= 0x80
				and c4 <= 0xBF
			then
				len = 4
			end
		end

		if len == 0 then
			-- 非法：记录第一处，替换为 U+FFFD，单字节前进
			if out == nil then
				out = {}
				bad_at = i
			end
			if i > run_start then
				out[#out + 1] = s:sub(run_start, i - 1)
			end
			out[#out + 1] = REPLACEMENT
			i = i + 1
			run_start = i
		else
			i = i + len
		end
	end

	if out == nil then
		return nil
	end

	if run_start <= n then
		out[#out + 1] = s:sub(run_start, n)
	end

	-- 坏字节附近的十六进制预览，便于人工定位
	local a = math.max(1, bad_at - 1)
	local b = math.min(n, bad_at + 7)
	local hex = {}
	for k = a, b do
		hex[#hex + 1] = string.format("%02x", s:byte(k))
	end

	return table.concat(out), bad_at, table.concat(hex, " ")
end

--[[
递归扫描 + 就地修复。
只改字符串值，不动 key，也不重建 table —— 保留 vim.empty_dict 等元表。
report 用于把「第一处非法」的信息回传给调用方。
]]
---@param v any
---@param depth integer
---@param report table
local function fix_value(v, depth, report)
	if type(v) == "string" then
		local fixed, at, hex = sanitize(v)
		if fixed then
			if not report.found then
				report.found, report.offset, report.hex = true, at, hex
			end
			return fixed
		end
		return v
	end

	if type(v) == "table" and depth < MAX_DEPTH then
		for k, val in pairs(v) do
			if type(val) == "string" then
				local fixed, at, hex = sanitize(val)
				if fixed then
					if not report.found then
						report.found, report.offset, report.hex = true, at, hex
					end
					v[k] = fixed
				end
			elseif type(val) == "table" then
				fix_value(val, depth + 1, report)
			end
		end
	end

	return v
end

--[[
在 params 里找 textDocument.uri（优先）或第一个 uri，用于把告警指到具体文件。
LSP 的 params 结构不固定，这里做一个有限深度的浅搜索即可。
]]
---@param v any
---@param depth integer
---@return string|nil
local function find_uri(v, depth)
	if type(v) ~= "table" or depth > 6 then
		return nil
	end

	local td = v.textDocument
	if type(td) == "table" and type(td.uri) == "string" then
		return td.uri
	end
	if type(v.uri) == "string" then
		return v.uri
	end

	for _, val in pairs(v) do
		if type(val) == "table" then
			local u = find_uri(val, depth + 1)
			if u then
				return u
			end
		end
	end
	return nil
end

--[[
守卫入口：检查并（必要时）修复一次消息的 params。
返回应当发送的 params（正常时就是原值）。
]]
---@param client vim.lsp.Client
---@param method string
---@param params any
---@return any
local function guard_params(client, method, params)
	local t = type(params)
	if t ~= "string" and t ~= "table" then
		return params
	end

	local report = { found = false }
	params = fix_value(params, 0, report)

	-- 增量 didChange 含非法字节时，危险的不只是 text 非法：compute_diff 给出的 range
	-- 也可能落在字符中间，rust-analyzer 会 panic「start of range should be a character boundary」。
	-- 直接用当前 buffer 的完整文本做一次全量替换（LSP 规定省略 range 的 contentChange
	-- 即替换整个文档），既保证合法，又让 server 与 buffer 重新对齐。
	-- 注意：同一 sync group 的多个 client 共享 contentChanges，第一个 client 就地修好后，
	-- 后面的 client 扫不到脏数据，因此用 bad_changes 记忆这张表，保证每个 client 都做全量替换。
	local bufnr = nil
	local dirty_changes = false
	if type(params) == "table" and method == "textDocument/didChange" and params.contentChanges then
		local changes = params.contentChanges
		dirty_changes = report.found or bad_changes[changes] == true
		if report.found then
			bad_changes[changes] = true
		end
	end

	if not report.found and not dirty_changes then
		return params
	end

	if dirty_changes then
		local uri = vim.tbl_get(params, "textDocument", "uri")
		local ok_uri, resolved = pcall(vim.uri_to_bufnr, uri)
		bufnr = ok_uri and resolved or nil
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
			-- 万一 buffer 层还没修（例如 on_lines 被抑制），这里再兜底一次
			local ok_full, full = pcall(vim.lsp._buf_get_full_text, bufnr)
			if ok_full and type(full) == "string" then
				params.contentChanges = { { text = sanitize(full) or full } }
			end
		end
	end

	-- 节流告警：只在真正检测到脏数据的那个 client 上报一次，共享表的后续 client 不重复报
	local key = string.format("%d:%s", client.id, method)
	local now = vim.uv.now()
	-- 若 buffer 层刚在同一事件里修复过，就不再重复告警
	local handled = bufnr ~= nil and (now - (buf_repaired_at[bufnr] or 0) < WARN_INTERVAL_MS)
	if report.found and not handled and now - (last_warn[key] or 0) >= WARN_INTERVAL_MS then
		last_warn[key] = now
		local uri = type(params) == "table" and find_uri(params, 0) or nil
		vim.notify(
			string.format(
				"[lsp-utf8-guard] %s 发送 %s 含非法 UTF-8\n  uri: %s\n  首个坏字节 @ %s  (hex: %s)\n  已替换/整篇替换后发送，避免 server 退出",
				client.name,
				method,
				uri or "<unknown>",
				tostring(report.offset),
				report.hex or "?"
			),
			vim.log.levels.WARN
		)
	end

	return params
end

--[[
============================================================
缓冲区修复：从源头保证 buffer 是合法 UTF-8
============================================================

【为什么还需要这一层】
  只在发送关口（wrapped notify/request）替换非法字节，会留下一个更隐蔽的后果：
  服务端内部文档与 Neovim buffer 的字节/字符长度发生错位。
  之后任何基于 buffer 真实位置计算的增量 didChange，range 都可能落在字符中间，
  rust-analyzer 会直接 panic：
      start of range should be a character boundary
  （实际崩溃见 ~/.local/state/nvim/logs/lsp.log，notification: textDocument/didChange）

  所以真正稳妥的做法是：非法字节一进入 buffer 就地修复，
  让 buffer 与所有 client / formatter / treesitter 看到的文本保持一致。

【做法】
  * nvim_buf_attach 的 on_lines 记录本次变更的行范围（开销极小）
  * on_lines 里用 vim.schedule 安排一次修复（避开 on_lines 回调内禁止改文本的限制），
    只扫描这次变更涉及的行；schedule 一定早于 LSP 的 debounce flush（默认 150ms）
  * 发现非法字节就整行替换（保持行数不变）；替换会再次触发 on_lines，
    但此时已无非法字节，因此不会死循环
  * 保存/恢复各窗口视图，避免修复时光标跳动

  这一层在 LSP flush 之前把 buffer 变成合法 UTF-8，
  所以 client 拿到的是合法文本；发送关口退化为兜底。
]]

local buf_attached = {}
local buf_dirty = {} ---@type table<integer, { [1]: integer, [2]: integer }>
local buf_repairing = {}
local buf_scheduled = {}
local buffer_guard_installed = false
local last_buffer_warn = {}

---@type fun(bufnr: integer)
local repair_buffer

---@param bufnr integer
local function attach_buf(bufnr)
	if buf_attached[bufnr] then
		return
	end
	buf_attached[bufnr] = true
	vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function(_, b, _, first, _, new_last)
			local d = buf_dirty[b]
			if not d then
				buf_dirty[b] = { first, new_last - 1 }
			else
				d[1] = math.min(d[1], first)
				d[2] = math.max(d[2], new_last - 1)
			end
			if not buf_scheduled[b] and not buf_repairing[b] then
				buf_scheduled[b] = true
				vim.schedule(function()
					buf_scheduled[b] = nil
					repair_buffer(b)
				end)
			end
		end,
		on_detach = function(_, b)
			buf_attached[b] = nil
			buf_dirty[b] = nil
			buf_repairing[b] = nil
			buf_scheduled[b] = nil
		end,
	})
end

---@param bufnr integer
repair_buffer = function(bufnr)
	if buf_repairing[bufnr] then
		return
	end
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end
	if not vim.bo[bufnr].modifiable then
		return
	end

	local nlines = vim.api.nvim_buf_line_count(bufnr)
	local range = buf_dirty[bufnr]
	buf_dirty[bufnr] = nil

	local first, last
	if range and range[1] <= range[2] then
		first = math.max(0, range[1])
		last = math.min(nlines - 1, range[2])
	else
		first, last = 0, nlines - 1
	end
	if first > last then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, first, last + 1, false)
	local hits = {}
	for i, line in ipairs(lines) do
		local fixed, at, hex = sanitize(line)
		if fixed then
			hits[#hits + 1] = { lnum = first + i - 1, fixed = fixed, at = at, hex = hex }
		end
	end
	if #hits == 0 then
		return
	end

	buf_repairing[bufnr] = true
	local ok, err = pcall(function()
		local views = {}
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(win) == bufnr then
				views[#views + 1] = {
					win = win,
					view = vim.api.nvim_win_call(win, function()
						return vim.fn.winsaveview()
					end),
				}
			end
		end
		for _, h in ipairs(hits) do
			vim.api.nvim_buf_set_lines(bufnr, h.lnum, h.lnum + 1, false, { h.fixed })
		end
		for _, v in ipairs(views) do
			if vim.api.nvim_win_is_valid(v.win) then
				vim.api.nvim_win_call(v.win, function()
					vim.fn.winrestview(v.view)
				end)
			end
		end
	end)
	buf_repairing[bufnr] = nil

	if not ok then
		vim.notify("[lsp-utf8-guard] 修复 buffer 失败: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	local now = vim.uv.now()
	buf_repaired_at[bufnr] = now
	if now - (last_buffer_warn[bufnr] or 0) >= WARN_INTERVAL_MS then
		last_buffer_warn[bufnr] = now
		local h = hits[1]
		vim.notify(
			string.format(
				"[lsp-utf8-guard] 检测到非法 UTF-8 并已就地修复\n  buffer: %s (第 %d 行)\n  首个坏字节 @ %s (hex: %s)\n  本次修复 %d 行",
				vim.api.nvim_buf_get_name(bufnr),
				h.lnum + 1,
				tostring(h.at),
				h.hex or "?",
				#hits
			),
			vim.log.levels.WARN
		)
	end
end

--- 安装缓冲区级守卫。全局只需调用一次（幂等）。
function M.setup_buffer_guard()
	if buffer_guard_installed then
		return
	end
	buffer_guard_installed = true

	local group = vim.api.nvim_create_augroup("UserLspUtf8BufferGuard", { clear = true })

	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWinEnter" }, {
		group = group,
		callback = function(args)
			attach_buf(args.buf)
		end,
	})

	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(b) then
			attach_buf(b)
		end
	end
end

--- 在 LspAttach 中调用。幂等：同一 client 只包一次。
---@param client vim.lsp.Client
function M.setup(client)
	if not client or client._utf8_guard_wrapped then
		return
	end
	if M.servers and not vim.tbl_contains(M.servers, client.name) then
		return
	end
	client._utf8_guard_wrapped = true

	-- 注意：Client 的方法是 `client:notify(...)` / `client:request(...)`，
	-- 即第一个参数是 self。这里必须保留同一个调用约定，否则自参会错位。
	local orig_notify = client.notify
	---@diagnostic disable-next-line: duplicate-set-field
	client.notify = function(self, method, params, ...)
		return orig_notify(self, method, guard_params(self, method, params), ...)
	end

	local orig_request = client.request
	---@diagnostic disable-next-line: duplicate-set-field
	client.request = function(self, method, params, ...)
		return orig_request(self, method, guard_params(self, method, params), ...)
	end
end

return M
