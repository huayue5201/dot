-- lua/local/ai/pi_bridge.lua
---@brief 给外部编码 agent（pi）读取"活着的 nvim"上下文的桥。
--
-- 为什么需要：pi 跑在 tmux 另一个 pane 里，它 `read` 拿到的是磁盘快照，
-- 看不到未保存的 buffer、光标位置、visual 选区、LSP 诊断、quickfix。
-- 这里开一个 RPC socket 并登记到 ~/.cache/nvim/pi-ctx/，让 pi 反向拉取。
--
-- 外部用法（一次性调用，无需常驻客户端）：
--   nvim --server <sock> --remote-expr \
--     'v:lua.require("local.ai.pi_bridge").handle("<base64(json)>")'
-- 请求 {"action": "state"} | {"action":"buffer","path":...,"from":..,"to":..}
--      | {"action":"diagnostics"} | {"action":"quickfix"} | {"action":"list"}
-- 返回 JSON 字符串（失败时 {"ok":false,"error":...}，不抛异常）。
--
-- 代码内容永远取内存 buffer（含未保存修改），找不到该文件时才回退磁盘。

local M = {}

local DIR = vim.fn.stdpath("cache") .. "/pi-ctx"
local PID = vim.fn.getpid()
local REG = string.format("%s/%d.json", DIR, PID)
local SOCK = string.format("%s/%d.sock", DIR, PID)

local attached = false
local last_reg = 0

local function now_ms()
	return math.floor(vim.uv.now())
end

local function buf_path(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return nil
	end
	if name:sub(1, 7) == "term://" or name:sub(1, 7) == "oil://" then
		return name
	end
	return vim.fn.fnamemodify(name, ":p")
end

--- 把绝对路径按 cwd 缩成相对路径，方便 pi 直接当文件路径用
local function rel(path)
	if not path then
		return nil
	end
	local cwd = vim.fn.getcwd() .. "/"
	if path:sub(1, #cwd) == cwd then
		return path:sub(#cwd + 1)
	end
	return path
end

--- 最近使用过的已列出 buffer（lastused 降序），用于给 pi 一点"你刚才在看什么"的线索
local function recent(limit)
	local out = {}
	for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		if info.name ~= "" and info.name:sub(1, 7) ~= "term://" then
			table.insert(out, { path = rel(info.name), lastused = info.lastused })
		end
	end
	table.sort(out, function(a, b)
		return a.lastused > b.lastused
	end)
	while #out > (limit or 10) do
		table.remove(out)
	end
	return out
end

--- visual 选区（仅当当前处于可视模式时）
local function visual()
	local mode = vim.fn.mode()
	if not (mode == "v" or mode == "V" or mode == "\22") then
		return nil
	end
	local s, e = vim.fn.getpos("v"), vim.fn.getpos(".")
	local sline, eline = s[2], e[2]
	local kind = mode == "V" and "line" or (mode == "\22" and "block" or "char")
	if sline == 0 or eline == 0 then
		return nil
	end
	if sline > eline then
		sline, eline = eline, sline
	end
	local lines = vim.api.nvim_buf_get_lines(0, sline - 1, eline, false)
	return { kind = kind, start_line = sline, end_line = eline, lines = lines }
end

--- 各 tab 的工作区（tab_workspace 用 :tcd 给每个 tab 独立 cwd，pi 需要知道你到底开着哪些项目）
local function tabs()
	local out = {}
	local cur = vim.fn.tabpagenr()
	for idx in ipairs(vim.fn.gettabinfo()) do
		local file
		local okw, win = pcall(vim.api.nvim_tabpage_get_win, idx)
		if okw then
			local okb, buf = pcall(vim.api.nvim_win_get_buf, win)
			if okb then
				file = rel(buf_path(buf))
			end
		end
		local okc, cwd = pcall(vim.fn.getcwd, -1, idx)
		table.insert(out, { index = idx, active = idx == cur, cwd = okc and cwd or nil, file = file })
	end
	return out
end

local function state()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local qf = vim.fn.getqflist({ size = 1, title = 1 })
	local diags = 0
	for _, d in pairs(vim.diagnostic.get()) do
		if d.bufnr and vim.api.nvim_buf_is_valid(d.bufnr) then
			diags = diags + 1
		end
	end
	return {
		ok = true,
		action = "state",
		pid = PID,
		sock = SOCK,
		cwd = vim.fn.getcwd(),
		bufnr = buf,
		path = rel(buf_path(buf)),
		filetype = vim.bo[buf].filetype,
		modified = vim.bo[buf].modified,
		mode = vim.fn.mode(),
		cursor = { line = cursor[1], col = cursor[2] + 1 },
		total_lines = vim.api.nvim_buf_line_count(buf),
		visual = visual(),
		diagnostic_count = diags,
		quickfix = { size = qf.size, title = qf.title },
		tabs = tabs(),
		buffers = recent(10),
	}
end

--- 请求的 path 对应哪个 buffer？找不到返回 nil（调用方回落磁盘）
local function find_buf(path)
	local want = vim.fn.fnamemodify(vim.fn.getcwd() .. "/" .. path, ":p")
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local p = buf_path(buf)
		if p and (p == want or vim.fn.fnamemodify(p, ":p") == want) then
			return buf
		end
	end
	return nil
end

local function buffer(req)
	local path = req.path
	local buf
	if path and path ~= "" then
		buf = find_buf(path)
	else
		buf = vim.api.nvim_get_current_buf()
		path = rel(buf_path(buf))
	end

	local lines
	local from = req.from or 1
	local to = req.to
	local disk = false
	local source = vim.api.nvim_buf_is_valid(buf or -1) and buf_path(buf) or nil

	if buf and vim.api.nvim_buf_is_valid(buf) then
		local total = vim.api.nvim_buf_line_count(buf)
		to = math.min(to or total, total)
		lines = vim.api.nvim_buf_get_lines(buf, from - 1, to, false)
		path = rel(buf_path(buf)) or path
		if vim.bo[buf].modified then
			disk = true -- 有未保存改动，内容与磁盘不同
		end
	else
		local abs = vim.fn.fnamemodify(vim.fn.getcwd() .. "/" .. (path or ""), ":p")
		if vim.fn.filereadable(abs) == 0 then
			return { ok = false, error = "file not found: " .. tostring(path) }
		end
		local all = vim.fn.readfile(abs)
		to = math.min(to or #all, #all)
		lines = {}
		for i = from, to do
			lines[#lines + 1] = all[i]
		end
		source = abs
	end

	local cap = req.max_lines or 2000
	local truncated = false
	if #lines > cap then
		lines = { unpack(lines, 1, cap) }
		to = from + cap - 1
		truncated = true
	end

	return {
		ok = true,
		action = "buffer",
		path = path,
		abs_path = source,
		from = from,
		to = to,
		total_lines = buf and vim.api.nvim_buf_line_count(buf) or nil,
		modified = disk,
		filetype = buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype or nil,
		lines = lines,
		truncated = truncated,
	}
end

local severity_name = { "ERROR", "WARN", "INFO", "HINT" }

local function diagnostics(req)
	local by_file, order = {}, {}
	local want = req.path and find_buf(req.path) or nil
	for _, d in ipairs(vim.diagnostic.get(want)) do
		local buf = d.bufnr
		local name = rel(buf_path(buf)) or "<unnamed>"
		if not by_file[name] then
			by_file[name] = {}
			order[#order + 1] = name
		end
		table.insert(by_file[name], {
			line = d.lnum + 1,
			col = (d.col or 0) + 1,
			severity = severity_name[d.severity] or "?",
			message = d.message,
			source = d.source,
		})
	end
	if #order == 0 then
		return { ok = true, action = "diagnostics", files = {}, clean = true }
	end
	local files = {}
	for _, name in ipairs(order) do
		table.insert(files, { path = name, items = by_file[name] })
	end
	return { ok = true, action = "diagnostics", files = files }
end

local function quickfix()
	local qf = vim.fn.getqflist({ items = 1, title = 1 })
	local items = {}
	for _, it in ipairs(qf.items or {}) do
		local path = it.bufnr and it.bufnr > 0 and buf_path(it.bufnr) or nil
		table.insert(items, {
			path = rel(path) or nil,
			line = it.lnum,
			col = it.col,
			text = it.text,
		})
		if #items >= 200 then
			break
		end
	end
	return { ok = true, action = "quickfix", title = qf.title, size = #items, items = items }
end

--- 扫描登记目录，列出所有活着的 nvim 实例（不看 req，供 pi 的 /nvim-pin 用）
function M.list()
	local out = {}
	local ok, names = pcall(vim.fn.readdir, DIR)
	if not ok then
		return { ok = true, action = "list", instances = {} }
	end
	for _, name in ipairs(names or {}) do
		if name:match("%.json$") then
			local txt = table.concat(vim.fn.readfile(DIR .. "/" .. name), "\n")
			local ok2, entry = pcall(vim.json.decode, txt)
			if ok2 and type(entry) == "table" then
				entry.self = (tostring(entry.pid) == tostring(PID))
				table.insert(out, entry)
			end
		end
	end
	table.sort(out, function(a, b)
		return (a.ts or 0) > (b.ts or 0)
	end)
	return { ok = true, action = "list", instances = out }
end

local handlers = {
	state = function()
		return state()
	end,
	buffer = buffer,
	diagnostics = diagnostics,
	quickfix = function()
		return quickfix()
	end,
	list = function()
		return M.list()
	end,
}

--- 写实例登记文件（pa 依据它找到 socket、判断哪个项目）
function M.registry()
	vim.fn.mkdir(DIR, "p")
	local buf = vim.api.nvim_get_current_buf()
	local entry = {
		pid = PID,
		sock = SOCK,
		cwd = vim.fn.getcwd(),
		name = vim.v.servername ~= "" and vim.v.servername or nil,
		file = rel(buf_path(buf)),
		ts = os.time(),
	}
	local f = io.open(REG, "w")
	if not f then
		return
	end
	f:write(vim.json.encode(entry))
	f:close()
	last_reg = now_ms()
end

--- 入口：开 socket + 登记 + 维护生命周期。init.lua 启动时调一次。
function M.attach()
	if attached then
		return
	end
	vim.fn.mkdir(DIR, "p")
	local ok, addr = pcall(vim.fn.serverstart, SOCK)
	if not ok then
		-- 上次异常退出留下的 socket 文件：删掉重试一次
		pcall(os.remove, SOCK)
		ok, addr = pcall(vim.fn.serverstart, SOCK)
	end
	if not ok then
		vim.notify("[ai.pi_bridge] serverstart failed: " .. tostring(addr), vim.log.levels.WARN)
		return
	end
	attached = true
	pcall(M.registry)

	local grp = vim.api.nvim_create_augroup("PiCtxBridge", { clear = true })
	local function touch()
		if now_ms() - last_reg < 2000 then
			return
		end
		pcall(M.registry)
	end
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "DirChanged" }, {
		group = grp,
		callback = function()
			last_reg = 0 -- 这些事件信息量大，别节流
			pcall(M.registry)
		end,
	})
	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, { group = grp, callback = touch })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = grp,
		callback = function()
			pcall(os.remove, REG)
			pcall(os.remove, SOCK)
		end,
	})
end

--- RPC 入口：接收 base64(json) 请求，返回 JSON 字符串。永不抛错。
function M.handle(b64)
	local ok, res = pcall(function()
		local req = vim.json.decode(vim.base64.decode(b64 or ""))
		local h = handlers[req.action]
		if not h then
			return { ok = false, error = "unknown action: " .. tostring(req.action) }
		end
		return h(req)
	end)
	if not ok then
		return vim.json.encode({ ok = false, error = tostring(res) })
	end
	return vim.json.encode(res)
end

return M
