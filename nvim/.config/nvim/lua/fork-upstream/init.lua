--- fork-upstream 状态组件
--- 依赖 dotfiles/bin/fork-upstream 的 --json 输出。
--- 自动检查一律 --no-fetch（只看已有远端引用），手动命令才真正 git fetch。

local M = {}

local CACHE_TTL = 30 -- 自动检查的缓存有效期（秒）
local DEBOUNCE = 300 -- BufEnter/DirChanged 去抖（毫秒）
local CACHE_FILE = vim.fs.joinpath(vim.fn.stdpath("cache"), "fork-upstream.json")

local cfg = {
	bin = "fork-upstream",
	timeout = 15000, -- 单次脚本超时（毫秒）
}

local cache = {} -- repo -> { at = os.time(), data = <json> }
local jobs = {} -- repo -> { obj = vim.SystemObj }（句柄用于识别过期回调）
local timers = {} -- repo -> uv_timer
local dir_repo = {} -- dir -> repo（只缓存正结果）
local save_pending = false
local missing_warned = false

-- ================================
-- 工具
-- ================================

local function notify(msg, level)
	vim.notify("fork-upstream: " .. msg, level or vim.log.levels.INFO)
end

--- 找到路径所在的 git 仓库根目录（纯 Lua 向上查找，无子进程）
local function repo_root(dir)
	dir = dir or vim.fn.getcwd()
	local hit = dir_repo[dir]
	if hit then
		return hit
	end
	local root = vim.fs.root(dir, ".git")
	if root then
		dir_repo[dir] = root
	end
	return root
end

--- 当前 buffer 所属仓库：buffer 路径优先，无路径时退到 cwd
local function current_repo(win)
	local buf = vim.api.nvim_win_get_buf(win or 0)
	local name = vim.api.nvim_buf_get_name(buf)
	local dir
	if name ~= "" and vim.bo[buf].buftype == "" then
		dir = vim.fs.dirname(name)
	else
		dir = vim.fn.getcwd()
	end
	return repo_root(dir)
end

local function read_cache_file()
	local ok, lines = pcall(vim.fn.readfile, CACHE_FILE)
	if not ok or not lines or #lines == 0 then
		return
	end
	local ok2, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok2 or type(decoded) ~= "table" then
		return
	end
	for repo, entry in pairs(decoded) do
		if type(entry) == "table" and type(entry.data) == "table" then
			cache[repo] = entry
		end
	end
end

local function save_cache_file()
	if save_pending then
		return
	end
	save_pending = true
	vim.defer_fn(function()
		save_pending = false
		local out = {}
		for repo, entry in pairs(cache) do
			out[repo] = { at = entry.at, data = entry.data }
		end
		local ok, encoded = pcall(vim.json.encode, out)
		if ok then
			pcall(vim.fn.mkdir, vim.fs.dirname(CACHE_FILE), "p")
			pcall(vim.fn.writefile, { encoded }, CACHE_FILE)
		end
	end, 1000)
end

local function emit(repo)
	vim.api.nvim_exec_autocmds("User", { pattern = "ForkUpstreamUpdate", data = repo })
end

-- ================================
-- 查询
-- ================================

--- 异步刷新一个仓库
--- @param repo string|nil
--- @param opts table|nil { fetch=boolean, force=boolean, fix=boolean, quiet=boolean, on_done=fun() }
function M.refresh(repo, opts)
	repo = repo or current_repo(0)
	if not repo then
		return
	end
	opts = opts or {}

	local entry = cache[repo]
	if not opts.force and entry and os.time() - entry.at < CACHE_TTL then
		if opts.on_done then
			opts.on_done()
		end
		return
	end

	-- 同一仓库同一时刻只跑一个任务（force 时杀掉旧的）
	if jobs[repo] then
		if not opts.force then
			return
		end
		local old = jobs[repo]
		jobs[repo] = nil
		pcall(function()
			old.obj:kill("sigterm")
		end)
	end

	local cmd = { cfg.bin, "--json", "-r", repo }
	if not opts.fetch then
		table.insert(cmd, "--no-fetch")
	end
	if opts.fix then
		table.insert(cmd, "--fix")
	end

	local handle = {}
	local ok, job = pcall(vim.system, cmd, { text = true, timeout = cfg.timeout }, function(obj)
		-- on_exit 是 fast event，所有 API 调用统一挪到主循环
		vim.schedule(function()
			-- 已被新的刷新取代：丢弃这次结果
			if jobs[repo] ~= handle then
				return
			end
			jobs[repo] = nil
			if obj.code ~= 0 then
				if not opts.quiet then
					notify(("检查失败 %s: %s"):format(repo, (obj.stderr or ""):gsub("%s+$", "")), vim.log.levels.WARN)
				end
				return
			end
			-- luanil: JSON null → Lua nil，避免 vim.NIL 被当成真值
			local ok2, data = pcall(vim.json.decode, obj.stdout or "", { luanil = { object = true, array = true } })
			if not ok2 or type(data) ~= "table" then
				if not opts.quiet then
					notify("无法解析输出: " .. tostring(obj.stdout), vim.log.levels.ERROR)
				end
				return
			end
			if data[1] then
				data = data[1]
			end
			cache[repo] = { at = os.time(), data = data }
			save_cache_file()
			emit(repo)
			if opts.on_done then
				opts.on_done()
			end
		end)
	end)

	if not ok then
		if not missing_warned then
			missing_warned = true
			notify(("找不到可执行文件 %s（检查 PATH，或 setup({ bin = ... })）"):format(cfg.bin), vim.log.levels.ERROR)
		end
		return
	end
	handle.obj = job
	jobs[repo] = handle
end

--- 去抖刷新（BufEnter / DirChanged 用）
local function schedule(repo, opts)
	if not repo then
		return
	end
	local timer = timers[repo]
	if timer then
		timers[repo] = nil
		pcall(timer.stop, timer)
		if not timer:is_closing() then
			pcall(timer.close, timer)
		end
	end
	timer = vim.uv.new_timer()
	timers[repo] = timer
	timer:start(
		DEBOUNCE,
		0,
		vim.schedule_wrap(function()
			-- 该 timer 可能已被后续 schedule() 关闭；重复 close 会报
			-- "handle is already closing"，先检查再关，且不阻断 refresh
			if not timer:is_closing() then
				pcall(timer.stop, timer)
				pcall(timer.close, timer)
			end
			if timers[repo] == timer then
				timers[repo] = nil
			end
			M.refresh(repo, opts)
		end)
	)
end

--- 同步读取当前仓库状态（不触发任何任务）
function M.status(win)
	local repo = current_repo(win)
	local entry = repo and cache[repo]
	return repo, entry and entry.data or nil, entry and entry.at or nil
end

-- ================================
-- 状态栏组件
-- ================================

local function hl(name, opts)
	vim.api.nvim_set_hl(0, name, opts)
end

local function define_highlights()
	local p = require("core.colors").palette
	hl("ForkUpstreamOK", { fg = p.green, bold = true })
	hl("ForkUpstreamBehind", { fg = p.yellow, bold = true })
	hl("ForkUpstreamBehindMany", { fg = p.red, bold = true })
	hl("ForkUpstreamAhead", { fg = p.gray })
	hl("ForkUpstreamError", { fg = p.red, bold = true })
end

--- 状态栏字符串（纯读缓存，绝不阻塞）
--- ↑N = 上游有新提交待合入，↓N = 本地独有提交
function M.component(win)
	local _, data = M.status(win)
	if not data then
		return ""
	end

	if data.error == "upstream-ref-missing" or data.error == "fork-without-upstream" then
		return "%#ForkUpstreamError# %*"
	end

	local parts = {}
	if (data.behind or 0) > 0 then
		local group = data.behind >= 10 and "ForkUpstreamBehindMany" or "ForkUpstreamBehind"
		table.insert(parts, ("%%#%s#↑%d%%*"):format(group, data.behind))
	end
	if (data.ahead or 0) > 0 then
		table.insert(parts, ("%%#ForkUpstreamAhead#↓%d%%*"):format(data.ahead))
	end
	if #parts == 0 then
		-- 没有 upstream 的仓库（自己的项目）不显示同步标记，避免误导
		if not data.has_upstream then
			return ""
		end
		return "%#ForkUpstreamOK#✓%*"
	end
	return table.concat(parts, " ")
end

-- ================================
-- float 详情
-- ================================

local function detail_lines(data)
	local lines = {}
	if not data then
		return { "尚未检查（运行 :ForkUpstream 刷新）" }
	end

	local head = ("%s  ·  %s  →  %s"):format(data.name or "?", data.branch or "?", data.remote or "?")
	if data.error == "fork-without-upstream" then
		table.insert(lines, head)
		table.insert(lines, "")
		table.insert(lines, "是 fork，但没有 upstream 远端")
		table.insert(lines, "运行 :ForkUpstreamFix 自动补上")
		return lines
	end
	if data.error == "upstream-ref-missing" then
		table.insert(lines, head)
		table.insert(lines, "")
		table.insert(lines, ("无法确定上游分支（%s 未 fetch？）"):format(data.remote or "?"))
		return lines
	end
	if data.error then
		return { head, "", "错误: " .. tostring(data.error) }
	end

	table.insert(lines, head)
	local status
	if (data.behind or 0) > 0 then
		status = ("落后 %d 提交 · 本地独有 %d"):format(data.behind, data.ahead or 0)
	else
		status = ("已同步 · 本地独有 %d"):format(data.ahead or 0)
	end
	table.insert(lines, status)
	if data.dirty then
		table.insert(lines, "有未提交改动")
	end

	if not data.has_upstream then
		table.insert(lines, "（没有 upstream，对比的是 origin）")
	end

	local last = data.last or {}
	if (data.behind or 0) > 0 and last.subject and last.subject ~= "" then
		table.insert(lines, "")
		table.insert(lines, ("上游最后: %s %s"):format(last.date or "", last.subject))
		for _, c in ipairs(data.commits or {}) do
			table.insert(lines, "  " .. c)
		end
	end
	return lines
end

function M.detail(repo, data)
	repo = repo or current_repo(0)
	if not repo then
		notify("当前 buffer 不在 git 仓库中", vim.log.levels.WARN)
		return
	end
	if not data then
		local entry = cache[repo]
		data = entry and entry.data or nil
	end

	local lines = detail_lines(data)
	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	width = math.min(math.max(width + 2, 40), math.max(vim.o.columns - 4, 40))
	local height = math.min(#lines, math.max(vim.o.lines - 6, 5))

	-- 已有 float 就复用
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(win)
		if vim.bo[b].filetype == "fork-upstream" then
			vim.api.nvim_win_close(win, true)
		end
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "fork-upstream"
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
		col = math.max(math.floor((vim.o.columns - width) / 2), 0),
		style = "minimal",
		border = "rounded",
		title = " fork-upstream · " .. vim.fs.basename(repo) .. " ",
		title_pos = "center",
	})
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
end

-- ================================
-- setup
-- ================================

function M.setup(opts)
	cfg = vim.tbl_extend("force", cfg, opts or {})
	if cfg.bin:sub(1, 1) == "~" then
		cfg.bin = vim.fn.expand(cfg.bin)
	end
	define_highlights()
	read_cache_file()

	vim.api.nvim_create_user_command("ForkUpstream", function()
		local repo = current_repo(0)
		if not repo then
			notify("当前 buffer 不在 git 仓库中", vim.log.levels.WARN)
			return
		end
		M.refresh(repo, {
			fetch = true,
			force = true,
			on_done = function()
				M.detail(repo)
			end,
		})
	end, { desc = "检查当前仓库上游（会 fetch）并显示详情" })

	vim.api.nvim_create_user_command("ForkUpstreamFix", function()
		local repo = current_repo(0)
		if not repo then
			notify("当前 buffer 不在 git 仓库中", vim.log.levels.WARN)
			return
		end
		M.refresh(repo, {
			fetch = true,
			force = true,
			fix = true,
			on_done = function()
				M.detail(repo)
			end,
		})
	end, { desc = "给缺 upstream 的 fork 自动补上远端" })

	vim.api.nvim_create_user_command("ForkUpstreamStatus", function()
		local repo, data = M.status(0)
		if not repo then
			notify("当前 buffer 不在 git 仓库中", vim.log.levels.WARN)
			return
		end
		notify(vim.inspect(data or "尚未检查"))
	end, { desc = "显示当前仓库的缓存状态" })

	local group = vim.api.nvim_create_augroup("ForkUpstream", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "DirChanged" }, {
		group = group,
		callback = function()
			schedule(current_repo(0))
		end,
	})

	-- 让状态栏立刻用上磁盘缓存（setup 可能早于状态栏初始化）
	emit(nil)
	schedule(current_repo(0))
end

return M
