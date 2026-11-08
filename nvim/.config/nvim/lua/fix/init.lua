-- ============================================================================
-- FIX 守卫：盯着 lua/fix/ 里每个「临时修复」的上游状态
-- ============================================================================
-- 痛点：lua/fix/*.lua 都是等上游修好就该删掉的东西，但没人提醒你「已经修了」，
-- 于是它们会一直躺着，成为升级时的一颗雷。
--
-- 做法：每个 fix 模块导出一张 M.meta（字段见下），本模块扫 **本地已安装的上游
-- 源码** + nvim-pack-lock.json 里的 rev 来判定状态，全程只读本地文件、不发网络
-- 请求（所以毫秒级、断网也能用）：
--
--   present  上游的 bug 代码还在            → 修还需要，什么都不用做
--   updated  rev 变了，但 bug 代码还在      → 上游动过，修依然需要（可能该看 diff）
--   removed  上游的 bug 代码没了            → 大概率已修，可以删
--   changed  上游代码变了且判不出修没修    → 人工复检
--   unknown  插件目录/标记文件找不到        → 改名/卸载/没装，手动看一眼
--
-- 判定顺序：buggy 标记命中 ⇒ 仍在；否则 fixed 标记命中 ⇒ 已修；否则 ⇒ 复检。
--
-- M.meta 字段（写在每个 fix 文件顶部）：
--   id           短标识，用于状态文件与通知去重（例 "neotest-golang#599"）
--   title        一句话说明 bug 是什么
--   plugin       pack 里的仓库目录名，也是 lock 文件里的 key（例 "neotest-golang"）
--   issue        上游 issue/PR 链接（选填，只用于展示）
--   baseline_rev 写这个 fix 时的上游 rev（短 sha 即可，跟 lock 里的 rev 前缀比较）
--   buggy        { { file = "相对插件根", contains = "..." } }  命中 ⇒ bug 仍在
--   fixed        { { file = ..., contains = ... } }             命中 ⇒ 已被修掉（选填）
--   cleanup      人工清理步骤（选填；require 点位会自动扫 lua/plugins/）
--
-- 新增一个临时修复时：写 M.meta + 在 plugins/*.lua 里 require 它，就自动被纳入监控。
-- 查看状态：:FixStatus（picker，<CR> 打开对应的 fix 文件）。
-- ============================================================================

local M = {}

local STATUS_LABEL = {
	present = "still needed",
	updated = "upstream changed",
	removed = "removable",
	changed = "needs review",
	unknown = "unknown",
}

-- 状态文件：记录「上次已经提醒过的 (id, rev, status)」，避免每次启动重复吵
local function state_path()
	local dir = vim.fn.stdpath("state")
	if dir == nil or dir == "" then
		dir = vim.fn.stdpath("cache")
	end
	return dir .. "/fix-guard.json"
end

local function read_file(path)
	local fd = io.open(path, "r")
	if not fd then
		return nil
	end
	local content = fd:read("*a")
	fd:close()
	return content
end

--- 收集 lua/fix/ 下所有带 M.meta 的模块（按 id 排序）
---@return table[]
function M.all()
	local out, seen = {}, {}
	for _, path in ipairs(vim.api.nvim_get_runtime_file("lua/fix/*.lua", true)) do
		local name = vim.fn.fnamemodify(path, ":t:r")
		if name ~= "init" and not seen[name] then
			seen[name] = true
			local module = "fix." .. name
			local item = { module = module, file = path, buggy = {} }
			local ok, fix = pcall(require, module)
			if ok and type(fix) == "table" and type(fix.meta) == "table" then
				item = vim.tbl_deep_extend("force", item, fix.meta)
				item.module, item.file = module, path
			else
				item.id = name
				item.title = "(missing M.meta, not monitored)"
			end
			out[#out + 1] = item
		end
	end
	table.sort(out, function(a, b)
		return (a.id or "") < (b.id or "")
	end)
	return out
end

--- pack 里已安装插件的根目录（先找 standard，再兜底 data 目录）
---@param name string
---@return string|nil
function M.plugin_dir(name)
	if type(name) ~= "string" then
		return nil
	end
	for _, root in ipairs(vim.opt.packpath:get()) do
		for _, kind in ipairs({ "start", "opt" }) do
			local hits = vim.fn.glob(root .. "/pack/*/" .. kind .. "/" .. name, false, true)
			if #hits > 0 then
				return hits[1]
			end
		end
	end
	local fallback = vim.fn.glob(vim.fn.stdpath("data") .. "/site/pack/*/opt/" .. name, false, true)
	return fallback[1]
end

--- 当前安装的 rev（lock 文件优先，退化为 git rev-parse）
---@param name string
---@param dir string|nil
---@return string|nil
function M.plugin_rev(name, dir)
	local lock = (vim.o.packlockfile ~= "" and vim.o.packlockfile) or (vim.fn.stdpath("data") .. "/nvim-pack-lock.json")
	if vim.fn.filereadable(lock) == 1 then
		local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(lock), "\n"))
		local entry = ok and type(data) == "table" and data.plugins and data.plugins[name]
		if type(entry) == "table" and type(entry.rev) == "string" then
			return entry.rev
		end
	end
	if dir then
		local out = vim.system({ "git", "-C", dir, "rev-parse", "HEAD" }, { text = true }):wait()
		if out.code == 0 then
			return (out.stdout or ""):gsub("%s+$", "")
		end
	end
	return nil
end

--- lua/plugins/*.lua 里 require 这个 fix 的点位（删 fix 时要一起删）
---@param module string
---@return string[]
function M.require_sites(module)
	local sites = {}
	local pattern = 'require("' .. module .. '")'
	for _, path in ipairs(vim.fn.globpath(vim.fn.stdpath("config") .. "/lua/plugins", "*.lua", false, true)) do
		local lines = vim.fn.readfile(path)
		for i, line in ipairs(lines) do
			if line:find(pattern, 1, true) then
				sites[#sites + 1] = string.format("%s:%d", vim.fn.fnamemodify(path, ":~:."), i)
			end
		end
	end
	return sites
end

--- 判定一条标记：{ file, contains }
---@return { found: boolean, missing: boolean, path: string, line: integer|nil }
local function eval_marker(dir, marker)
	local path = dir .. "/" .. marker.file
	local content = read_file(path)
	if content == nil then
		return { found = false, missing = true, path = path }
	end
	if type(marker.contains) ~= "string" then
		return { found = true, missing = false, path = path }
	end
	local from = 1
	while true do
		local s = content:find(marker.contains, from, true)
		if s == nil then
			break
		end
		local line = select(2, content:sub(1, s):gsub("\n", "")) + 1
		return { found = true, missing = false, path = path, line = line }
	end
	return { found = false, missing = false, path = path }
end

--- 评估单个 meta（不依赖 M.all，方便测试）
---@param meta table
---@return table
function M._evaluate(meta)
	local dir = M.plugin_dir(meta.plugin)
	local row = {
		meta = meta,
		dir = dir,
		rev = dir and M.plugin_rev(meta.plugin, dir) or nil,
		buggy_hits = {},
		fixed_hits = {},
		missing = {},
	}
	row.rev_changed = (function()
		local base, rev = meta.baseline_rev, row.rev
		if type(base) ~= "string" or type(rev) ~= "string" or base == "" then
			return false
		end
		return rev:sub(1, #base) ~= base
	end)()

	for _, marker in ipairs(meta.buggy or {}) do
		local r = eval_marker(dir or "", marker)
		if r.missing then
			row.missing[#row.missing + 1] = r.path
		elseif r.found then
			row.buggy_hits[#row.buggy_hits + 1] = { marker = marker, hit = r }
		end
	end
	for _, marker in ipairs(meta.fixed or {}) do
		local r = eval_marker(dir or "", marker)
		if r.missing then
			row.missing[#row.missing + 1] = r.path
		elseif r.found then
			row.fixed_hits[#row.fixed_hits + 1] = { marker = marker, hit = r }
		end
	end

	local total_markers = #(meta.buggy or {}) + #(meta.fixed or {})
	if dir == nil or (total_markers > 0 and #row.missing == total_markers) then
		row.status = "unknown"
	elseif #row.buggy_hits > 0 then
		row.status = row.rev_changed and "updated" or "present"
	elseif #row.fixed_hits > 0 then
		row.status = "removed"
	else
		row.status = "changed"
	end
	return row
end

--- 全量检查
---@return table[]
function M.check()
	local rows = {}
	for _, meta in ipairs(M.all()) do
		if meta.plugin then
			rows[#rows + 1] = M._evaluate(meta)
		end
	end
	return rows
end

--- 需要人动手的行（removed / changed / unknown）
---@param rows table[]
---@return table[]
function M.actionable(rows)
	local out = {}
	for _, row in ipairs(rows or M.check()) do
		if row.status ~= "present" and row.status ~= "updated" then
			out[#out + 1] = row
		end
	end
	return out
end

--- 生成一条 row 的可读详情（picker preview 也用这个）
---@param row table
---@return string[]
function M.describe(row)
	local meta = row.meta
	local lines = {}
	local function add(fmt, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt
	end

	add("Status: %s (%s)", STATUS_LABEL[row.status] or row.status, row.status)
	add("Fix: %s — %s", meta.id or "?", meta.title or "")
	if meta.issue then
		add("Upstream: %s", meta.issue)
	end
	if row.rev then
		add(
			"rev: %s%s",
			row.rev:sub(1, 12),
			row.rev_changed and ("(when fix was written: " .. tostring(meta.baseline_rev) .. ")") or "(unchanged)"
		)
	end
	if row.dir == nil then
		add("Plugin directory: cannot find %s (renamed or not installed?)", tostring(meta.plugin))
	end

	if #row.buggy_hits > 0 then
		add("")
		add("Still matches bug markers:")
		for _, h in ipairs(row.buggy_hits) do
			add("  %s:%s  %s", h.marker.file, tostring(h.hit.line or "-"), h.marker.contains)
		end
	elseif #row.fixed_hits > 0 then
		add("")
		add("Matches 'fixed' markers:")
		for _, h in ipairs(row.fixed_hits) do
			add("  %s:%s  %s", h.marker.file, tostring(h.hit.line or "-"), h.marker.contains)
		end
	end
	if #row.missing > 0 then
		add("")
		add("Marker files do not exist (upstream may have refactored):")
		for _, p in ipairs(row.missing) do
			add("  %s", p)
		end
	end

	if row.status == "removed" or row.status == "changed" then
		add("")
		add("Cleanup steps:")
		add("  1. Delete %s", vim.fn.fnamemodify(meta.file or "", ":~:."))
		local sites = M.require_sites(meta.module or "")
		if #sites == 0 then
			add('  2. no require("%s") found in lua/plugins/ (already deleted?)', meta.module or "?")
		else
			for i, site in ipairs(sites) do
				add('  %d. Delete the require("%s") line in %s', i + 1, site, meta.module)
			end
		end
		for _, step in ipairs(meta.cleanup or {}) do
			add("  * %s", step)
		end
	end
	return lines
end

--- picker 展示（:FixStatus）
function M.report()
	local rows = M.check()
	if #rows == 0 then
		vim.notify("No temporary fixes to monitor in lua/fix/", vim.log.levels.INFO)
		return
	end
	local order = { removed = 0, changed = 1, updated = 2, unknown = 3, present = 4 }
	table.sort(rows, function(a, b)
		local oa, ob = order[a.status] or 9, order[b.status] or 9
		return oa == ob and (a.meta.id or "") < (b.meta.id or "") or oa < ob
	end)

	require("ui.picker").pick({
		title = "FIX guard (upstream status of temporary fixes in lua/fix/)",
		items = rows,
		text = function(row)
			return string.format(
				"[%s] %s — %s",
				STATUS_LABEL[row.status] or row.status,
				row.meta.id or "?",
				row.meta.title or ""
			)
		end,
		preview = function(row)
			return M.describe(row)
		end,
		on_choose = function(row)
			-- E812：tab_workspace 的 autocmd 在 :edit 期间会换 buffer，:edit 因此报
			-- "Autocommands changed buffer or buffer name"，但文件其实已经打开，吞掉即可
			pcall(vim.cmd.edit, vim.fn.fnameescape(row.meta.file))
		end,
	})
end

--- 启动时的静默检查：只在「可删 / 需复检 / 无法判定」且与上次提醒不同时才通知
---@param opts table
function M.notify_if_news(opts)
	local rows = M.actionable()
	if #rows == 0 then
		return
	end

	local path = state_path()
	local state = {}
	if vim.fn.filereadable(path) == 1 then
		local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
		if ok and type(data) == "table" then
			state = data
		end
	end

	local news, seen = {}, {}
	for _, row in ipairs(rows) do
		local key = string.format("%s|%s|%s", row.meta.id or "?", tostring(row.rev or "-"), row.status)
		local last = state[row.meta.id or "?"]
		if type(last) ~= "table" or last.key ~= key then
			news[#news + 1] = row
			seen[row.meta.id or "?"] = { key = key, status = row.status, rev = row.rev }
		end
	end
	if #news == 0 then
		return
	end

	for id, entry in pairs(seen) do
		state[id] = entry
	end
	local ok, encoded = pcall(vim.json.encode, state)
	if ok then
		vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
		vim.fn.writefile(vim.split(encoded, "\n"), path)
	end

	local parts = {}
	for _, row in ipairs(news) do
		parts[#parts + 1] = string.format("%s: %s", STATUS_LABEL[row.status] or row.status, row.meta.id or "?")
	end
	vim.notify(
		string.format(
			"lua/fix/ has %d item(s) to handle — %s\nSee :FixStatus for details",
			#news,
			table.concat(parts, "; ")
		),
		vim.log.levels.WARN
	)
	if opts and opts.open_on_news then
		M.report()
	end
end

---@param opts table|nil
function M.setup(opts)
	opts = vim.tbl_deep_extend("force", { check_on_startup = true, delay = 3000, open_on_news = false }, opts or {})

	vim.api.nvim_create_user_command("FixStatus", function()
		M.report()
	end, { desc = "Watch upstream status of temporary fixes in lua/fix/ (prompts removal once fixed)" })

	if opts.check_on_startup then
		vim.defer_fn(function()
			pcall(M.notify_if_news, opts)
		end, opts.delay)
	end
end

return M
