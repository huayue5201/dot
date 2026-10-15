---code lens 渲染 / 鼠标点击 / 悬停高亮
---
---背景：Neovim 0.13 的 `vim.lsp.codelens.enable` 能渲染透镜（▶ Run / ⚙ Debug），
---但它把高亮组硬编码为 `LspCodeLens` / `LspCodeLensSeparator`，无法在鼠标悬停到
---某个透镜时给出反馈。这里改为自己请求并渲染透镜，从而支持：
---  1. 鼠标悬停到某个透镜 → 该透镜高亮（CodeLensHover）
---  2. 鼠标点击透镜 → 执行（等价于 lens.command）
---服务端协议不变（textDocument/codeLens + codeLens/resolve）。
---注意：启用本模块后不要再调用 `vim.lsp.codelens.enable`，否则两套渲染会互相覆盖。
---`vim.lsp.codelens.run()`（例如 `gO`）仍可独立工作（它会自行请求一次）。

local M = {}

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

local hl_ready = false
local function setup_highlights()
	if hl_ready then
		return
	end
	hl_ready = true
	vim.api.nvim_set_hl(0, "CodeLensTitle", { link = "LspCodeLens", default = true })
	vim.api.nvim_set_hl(0, "CodeLensSep", { link = "LspCodeLensSeparator", default = true })
	vim.api.nvim_set_hl(0, "CodeLensHover", { link = "Visual", default = true })
end

---@param bufnr integer
---@return string encoding
local function buf_encoding(bufnr)
	local enc = vim.bo[bufnr].fileencoding
	if enc and enc ~= "" then
		return enc
	end
	return "utf-8"
end

---透镜虚拟文本的前导空格数（用 start_col 这个字节列生成空格）
---@param bufnr integer
---@param entry CodeLensEntry
---@return integer
local function lens_indent(bufnr, entry)
	local r = entry.lens.range
	local client = vim.lsp.get_client_by_id(entry.client_id)
	local enc = (client and client.offset_encoding) or buf_encoding(bufnr)
	if vim.range and vim.range.lsp then
		local ok, range = pcall(vim.range.lsp, bufnr, r, enc)
		if ok and range then
			return range.start_col
		end
	end
	local ln = r.start.line
	local text = vim.api.nvim_buf_get_lines(bufnr, ln, ln + 1, false)[1] or ""
	local char = r.start.character or 0
	local ok, byte = pcall(vim.str_byteindex, text, char, enc == "utf-16")
	return (ok and byte) or char
end

---@param entry CodeLensEntry
---@return string
local function lens_title(entry)
	return (entry.lens.command and entry.lens.command.title) or ""
end

---构建一行的 virt_text（空格 + title1 + " | " + title2 ...），hover_idx 对应项使用高亮组
---@param bufnr integer
---@param entries CodeLensEntry[]
---@param hover_idx integer|nil
---@return string|table[][] chunks
local function build_chunks(bufnr, entries, hover_idx)
	local chunks = { { string.rep(" ", lens_indent(bufnr, entries[1])), "CodeLensSep" } }
	for i, e in ipairs(entries) do
		if i > 1 then
			chunks[#chunks + 1] = { " | ", "CodeLensSep" }
		end
		local hl = (i == hover_idx) and "CodeLensHover" or "CodeLensTitle"
		chunks[#chunks + 1] = { lens_title(e), hl }
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

	if st.marks[row] then
		pcall(vim.api.nvim_buf_del_extmark, bufnr, ns, st.marks[row])
		st.marks[row] = nil
	end
	local ok, id = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
		virt_lines = { build_chunks(bufnr, entries, hover_idx) },
		virt_lines_above = true,
	})
	if ok then
		st.marks[row] = id
	end
end

---全量重绘
---@param bufnr integer
local function render(bufnr)
	local st = bufs[bufnr]
	if not st or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	st.marks = {}

	local rows = {}
	for _, e in ipairs(st.lenses) do
		local l = e.lens
		if l and l.range and l.range.start and lens_title(e) ~= "" then
			local row = l.range.start.line
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

---向所有已注册 client 请求透镜并渲染
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
		if c then
			clients[#clients + 1] = c
		end
	end
	if #clients == 0 then
		st.lenses = {}
		render(bufnr)
		return
	end

	local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
	local acc = {}
	local finished = 0
	local function finish()
		finished = finished + 1
		if finished < #clients then
			return
		end
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

	for _, client in ipairs(clients) do
		client:request("textDocument/codeLens", params, function(err, result)
			if err or type(result) ~= "table" then
				return finish()
			end
			local n = #result
			if n == 0 then
				return finish()
			end
			local done = 0
			for _, lens in ipairs(result) do
				resolve_lens(client, bufnr, lens, function(resolved)
					if resolved and resolved.range then
						acc[#acc + 1] = { client_id = client.id, lens = resolved }
					end
					done = done + 1
					if done == n then
						finish()
					end
				end)
			end
		end, bufnr)
	end
end

---立即刷新
---@param bufnr integer
function M.refresh(bufnr)
	local st = bufs[bufnr]
	if not st then
		return
	end
	if st.timer then
		pcall(st.timer.stop, st.timer)
		pcall(st.timer.close, st.timer)
		st.timer = nil
	end
	st.gen = st.gen + 1
	request(bufnr, st.gen)
end

---防抖刷新
---@param bufnr integer
function M.schedule_refresh(bufnr)
	local st = bufs[bufnr]
	if not st then
		return
	end
	if st.timer then
		pcall(st.timer.stop, st.timer)
		pcall(st.timer.close, st.timer)
	end
	st.timer = vim.defer_fn(function()
		if bufs[bufnr] then
			bufs[bufnr].timer = nil
			M.refresh(bufnr)
		end
	end, 300)
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
	local line = mouse.line
	if not line or line < 1 then
		return nil
	end
	local row = line - 1
	local entries = st.rows[row]
	if not entries or #entries == 0 then
		return nil
	end
	-- 虚拟行/真实行区分：透镜渲染在函数行上方一格（virt_lines_above）
	local real = vim.fn.screenpos(win, line, 1)
	if not (real and real.row and real.row > 0 and mouse.screenrow == real.row - 1) then
		return nil
	end
	local wi = vim.fn.getwininfo(win)[1]
	local decol = mouse.wincol - ((wi and wi.textoff) or 0) -- 1-based 显示列
	local col = lens_indent(bufnr, entries[1])
	for i, e in ipairs(entries) do
		local width = math.max(vim.fn.strdisplaywidth(lens_title(e)), 1)
		if decol >= col + 1 and decol <= col + width then
			return row, i, e
		end
		col = col + width + 3 -- " | "
	end
	return nil
end

M._mouse_lens = mouse_lens

---当前行是否有 code lens（1-based 行；用于 gO 的虚拟行偏移判断）
---@param bufnr integer
---@param line integer 1-based
---@return boolean
function M.lens_on_line(bufnr, line)
	local st = bufs[bufnr]
	if not st or not st.rows then
		return false
	end
	return st.rows[line - 1] ~= nil
end

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
	local client = vim.lsp.get_client_by_id(entry.client_id)
	if client and entry.lens.command then
		-- 点击来自 expr 映射，此处处于 textlock，直接执行会触发
		-- E565（not allowed to change text or window），故调度到安全上下文。
		local command = entry.lens.command
		vim.schedule(function()
			local c = vim.lsp.get_client_by_id(entry.client_id)
			if c then
				c:exec_cmd(command, { bufnr = bufnr })
			end
		end)
	end
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

local refresh_installed = false
local function install_server_refresh()
	if refresh_installed then
		return
	end
	refresh_installed = true
	local orig = vim.lsp.handlers["workspace/codeLens/refresh"]
	vim.lsp.handlers["workspace/codeLens/refresh"] = function(err, result, ctx, config)
		for bufnr in pairs(bufs) do
			if vim.api.nvim_buf_is_valid(bufnr) then
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
	setup_highlights()
	install_detach()
	install_server_refresh()

	if not bufs[bufnr] then
		bufs[bufnr] = { clients = {}, lenses = {}, rows = {}, marks = {}, gen = 0 }

		local grp = vim.api.nvim_create_augroup("LspCodeLens" .. bufnr, { clear = true })
		vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufWritePost" }, {
			group = grp,
			buffer = bufnr,
			callback = function()
				M.schedule_refresh(bufnr)
			end,
		})
		vim.api.nvim_create_autocmd("BufWipeout", {
			group = grp,
			buffer = bufnr,
			callback = function()
				local s = bufs[bufnr]
				if s and s.timer then
					pcall(s.timer.stop, s.timer)
					pcall(s.timer.close, s.timer)
				end
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

return M
