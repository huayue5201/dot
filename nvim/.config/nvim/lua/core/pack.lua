-- 插件管理：安装 / 更新 / 锁文件 / 版本全部交给 Neovim 自带的 vim.pack。
-- 加载策略是「全 eager」：启动时把所有插件 packadd 一遍，不使用任何懒加载代理。
--
-- 为什么不再用 zpack：它的 cmd / keys / module 代理会引入一类很难查的 bug
-- （首次按键只加载不执行、命令代理丢 register/range、module 懒加载走 :packadd!
-- 不 source plugin/ 于是命令根本不存在）。eager 之后这些问题从根上不存在。
--
-- spec 写在 lua/plugins/*.lua，沿用 lazy.nvim 的写法（旧的懒加载字段已清理干净）：
--   * 生效的字段：src(第 1 位) / dir / name / main / version / branch / tag / commit
--                / sem_version / dependencies / init / config / opts / build / priority / enabled
--   * keys：注册成普通映射（不要写纯 lhs 的分组标签，那会变成空映射）
--   * 不识别（写了也无效）：event / ft / cmd / module / lazy

local M = {}

local config_dir = vim.fn.stdpath("config")
local spec_dir = vim.fs.joinpath(config_dir, "lua", "plugins")

-- 锁文件放到 data 目录，避免污染配置仓库。必须在第一次 vim.pack 调用之前设置。
if vim.fn.exists("+packlockfile") == 1 then
	vim.o.packlockfile = vim.fs.joinpath(vim.fn.stdpath("data"), "nvim-pack-lock.json")
end

local errors = {}

-- NVIM_PACK_PROFILE=1 nvim  打印每个插件加载耗时（调试用，平时零开销）
local profile = vim.env.NVIM_PACK_PROFILE == "1"
local profile_rows = {}
local phase_rows = {}

-- 阶段计时（仅 NVIM_PACK_PROFILE=1 时生效）
local function phase(name, fn, ...)
	if not profile then
		return fn(...)
	end
	local t0 = vim.uv.hrtime()
	local a, b, c = fn(...)
	phase_rows[#phase_rows + 1] = { ms = (vim.uv.hrtime() - t0) / 1e6, name = name }
	return a, b, c
end

-- 本次启动新装的插件（src 集合）：只有它们需要跑 build
local fresh = {}

local function fail(fmt, ...)
	errors[#errors + 1] = fmt:format(...)
end

local function report_errors()
	if #errors == 0 then
		return
	end
	local msg = table.concat(errors, "\n")
	vim.schedule(function()
		vim.notify("插件加载有问题:\n" .. msg, vim.log.levels.ERROR)
	end)
end

----------------------------------------------------------------------
-- spec 收集与归一化
----------------------------------------------------------------------

local function derive_name(source)
	local base = vim.fs.basename((source:gsub("/+$", "")))
	return (base:gsub("%.git$", ""))
end

local function is_git_url(source)
	return source:match("^%a[%w+.-]*://") ~= nil or source:match("^[%w_.-]+@[^/]+:") ~= nil
end

local function is_local_path(source)
	return source:match("^/") ~= nil or source:match("^~") ~= nil or source:match("^%.") ~= nil
end

local function normalize_version(spec)
	if spec.version == false then
		return nil
	end
	if spec.version ~= nil then
		return spec.version
	end
	if spec.sem_version then
		return vim.version.range(spec.sem_version)
	end
	return spec.branch or spec.tag or spec.commit
end

---@param raw string|table
---@param order integer 声明顺序（用作 priority 相同时的稳定次序）
---@return table?
local function normalize_spec(raw, order)
	local spec
	if type(raw) == "string" then
		spec = { raw }
	elseif type(raw) == "table" then
		spec = vim.deepcopy(raw)
	else
		return nil
	end

	-- dir 优先：本地 fork 会同时写上游字符串和 dir，dir 才是真正想要的安装源
	local source = spec.dir or spec[1] or spec.src or spec.url
	if type(source) ~= "string" then
		return nil
	end

	local name = spec.name or derive_name(source)

	local src = source
	if is_local_path(source) then
		src = (vim.fn.fnamemodify(vim.fn.expand(source), ":p"):gsub("/+$", ""))
	elseif not is_git_url(source) then
		src = "https://github.com/" .. source
	end

	spec[1] = nil
	spec.src = src
	spec.name = name
	spec.version = normalize_version(spec)
	spec._order = order

	return spec
end

local by_src = {}
local order = {}

local function register(spec)
	if not spec then
		return nil
	end
	local existing = by_src[spec.src]
	if existing then
		-- 同一插件被多个文件声明：补全缺失字段，dependencies 追加
		for k, v in pairs(spec) do
			if k == "dependencies" then
				existing.dependencies = existing.dependencies or {}
				vim.list_extend(existing.dependencies, v)
			elseif existing[k] == nil then
				existing[k] = v
			end
		end
		return existing
	end
	by_src[spec.src] = spec
	order[#order + 1] = spec
	return spec
end

-- 一个 spec 文件可能返回「单个 spec」或「spec 列表」。判定依据：
--   * 第 1 位是字符串 → 单个 spec（仓库名就写在 [1]）
--   * 第 1 位是表   → spec 列表
--   * 没有第 1 位   → 顶层出现已知 spec 字段即为单个 spec（本地 fork 只写 dir/name 的情况）
-- 这一步不能搞错：把「单个 spec」当成列表遍历，只会取到 [1] 那个仓库名字符串，
-- 整个 spec 的 dependencies / config / keys 全部丢失。
local SPEC_FIELDS = {
	"dir",
	"name",
	"main",
	"config",
	"init",
	"opts",
	"build",
	"dependencies",
	"version",
	"branch",
	"tag",
	"commit",
	"sem_version",
	"priority",
	"enabled",
	"keys",
	"cond",
	"virtual",
}
local function is_single_spec(t)
	if type(t[1]) == "string" then
		return true
	end
	if type(t[1]) == "table" then
		return false
	end
	for _, field in ipairs(SPEC_FIELDS) do
		if t[field] ~= nil then
			return true
		end
	end
	return false
end

local function collect()
	local files = {}
	for entry, kind in vim.fs.dir(spec_dir) do
		if kind == "file" and entry:match("%.lua$") then
			files[#files + 1] = entry
		elseif kind == "directory" and vim.fn.filereadable(vim.fs.joinpath(spec_dir, entry, "init.lua")) == 1 then
			files[#files + 1] = entry
		end
	end
	table.sort(files)

	for i, file in ipairs(files) do
		local mod = "plugins." .. file:gsub("%.lua$", "")
		local ok, ret = pcall(require, mod)
		if not ok then
			fail("spec %s 加载失败: %s", mod, ret)
		elseif type(ret) == "table" then
			local items = is_single_spec(ret) and { ret } or ret
			for _, raw in ipairs(items) do
				register(normalize_spec(raw, i))
			end
		end
	end

	-- 展开 dependencies（字符串 / 内联 spec 都可以），并记录边
	local i = 1
	while i <= #order do
		local spec = order[i]
		local list = spec.dependencies
		spec._deps = {}
		if list then
			list = type(list) == "table" and list or { list }
			for _, dep in ipairs(list) do
				local dep_spec = register(normalize_spec(dep, spec._order))
				if dep_spec then
					spec._deps[#spec._deps + 1] = dep_spec
				end
			end
		end
		i = i + 1
	end
end

----------------------------------------------------------------------
-- 工具
----------------------------------------------------------------------

-- 「第二波」：这些插件的 config 只在用户真正用到时才需要，放到首帧渲染之后再跑，
-- 能省掉 ~200ms 白屏时间。它们写在 plugin/ 里的命令/映射在启动时就已经 source 好了，
-- 晚一点 setup 只影响"第一次用之前要已经 setup 完"，不影响命令存在性。
--
-- 只在「裸启动」时延后：带文件参数（nvim foo.md）或脚本化（-c/-S/-l/--cmd/+cmd）时，
-- VimEnter 之前就已经在读文件、跑命令，延后会让 FileType 自动命令或 -c 找不到插件，
-- 所以那些情况一律保持全 eager。
local DEFER_HEAVY = true
local deferred = {
	["obsidian.nvim"] = true,
	["codecompanion.nvim"] = true,
	["treesj"] = true,
	["neotest"] = true,
	["codediff.nvim"] = true,
	["neogit"] = true,
	["atlas.nvim"] = true,
	["cash.nvim"] = true,
	["kulala.nvim"] = true,
	["crates.nvim"] = true,
	["render-markdown.nvim"] = true,
}

local function should_defer()
	if vim.env.NVIM_PACK_EAGER == "1" then
		return false -- 调试/脚本：强制全 eager
	end
	if vim.env.NVIM_PACK_DEFER == "1" then
		return true -- 调试：强制延后
	end
	if not DEFER_HEAVY then
		return false
	end
	if vim.fn.argc() > 0 then
		return false -- 启动时就打开了文件，它的 FileType 在 VimEnter 之前就触发了
	end
	for _, arg in ipairs(vim.v.argv) do
		if arg == "-c" or arg == "--cmd" or arg == "-S" or arg == "-l" or arg == "-lua" then
			return false
		end
		if arg:sub(1, 1) == "+" then
			return false -- nvim +cmd
		end
	end
	return true
end

local function priority_of(spec)
	return type(spec.priority) == "number" and spec.priority or 50
end

local function is_enabled(spec)
	local v = spec.enabled
	if v == nil then
		v = spec.cond
	end
	if v == nil then
		return true
	end
	if type(v) == "function" then
		local ok, res = pcall(v)
		return ok and res ~= false
	end
	return v ~= false
end

local function pack_path(name)
	return vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt", name)
end

local function source_after_plugin(path)
	-- 绝大多数插件没有 after/plugin，先 stat 一下省掉两次 glob
	if not vim.uv.fs_stat(path .. "/after/plugin") then
		return
	end
	for _, file in ipairs(vim.fn.glob(path .. "/after/plugin/**/*.vim", false, true)) do
		local ok, err = pcall(vim.cmd.source, file)
		if not ok then
			fail("source %s 失败: %s", file, err)
		end
	end
	for _, file in ipairs(vim.fn.glob(path .. "/after/plugin/**/*.lua", false, true)) do
		local ok, err = pcall(vim.cmd.source, file)
		if not ok then
			fail("source %s 失败: %s", file, err)
		end
	end
end

-- "obsidian.nvim" / "nvim-chainsaw" 这类仓库名并不是 Lua 模块名，
-- 去掉 nvim 前后缀与标点后再比较（仓库名 → Lua 模块名的常见约定）。
local function normalize_mod_name(name)
	return (name:lower():gsub("^n?vim%-", ""):gsub("%.n?vim$", ""):gsub("[%.%-_]", ""))
end

-- 多个 spec 声明同一个 lhs 时，第一个生效，避免互相覆盖后找不到来源
local key_owner = {}

local function resolve_main(spec, path)
	if spec.main then
		return spec.main
	end
	local name = spec.name
	if not name then
		return nil
	end
	if name:match("^mini%.") and name ~= "mini.nvim" then
		return name
	end
	local target = normalize_mod_name(name)
	local ok, iter = pcall(vim.fs.dir, path .. "/lua")
	if ok then
		for entry, kind in iter do
			if kind == "directory" or kind == "link" or entry:match("%.lua$") then
				local mod = (entry:gsub("%.lua$", ""))
				if normalize_mod_name(mod) == target then
					return mod
				end
			end
		end
	end
	return name -- 兜底：直接按目录名 require
end

local function plugin_object(spec)
	return {
		name = spec.name,
		dir = pack_path(spec.name),
		path = pack_path(spec.name),
		spec = spec,
		dependencies = vim.tbl_map(function(d)
			return d.name
		end, spec._deps or {}),
	}
end

----------------------------------------------------------------------
-- 各阶段：build / init / load(config, keys)
----------------------------------------------------------------------

local function run_build(spec)
	local build = spec.build
	if not build then
		return
	end
	local ok, err
	if type(build) == "function" then
		ok, err = pcall(build, plugin_object(spec))
	elseif type(build) == "string" then
		ok, err = pcall(vim.cmd, (build:gsub("^%s*:%%?", "")))
	end
	if not ok then
		fail("build %s 失败: %s", spec.name, err)
	end
end

local function run_init(spec)
	if type(spec.init) == "function" then
		local ok, err = pcall(spec.init, plugin_object(spec))
		if not ok then
			fail("init %s 失败: %s", spec.name, err)
		end
	end
end

local function resolve_opts(spec, plugin)
	local opts = spec.opts
	if type(opts) == "function" then
		local ok, res = pcall(opts, plugin, {})
		if not ok then
			fail("opts %s 失败: %s", spec.name, res)
			return {}
		end
		opts = res
	end
	return type(opts) == "table" and opts or {}
end

local function run_config(spec, plugin)
	local has_opts = spec.opts ~= nil
	local opts = resolve_opts(spec, plugin)

	if type(spec.config) == "function" then
		local ok, err = pcall(spec.config, plugin, opts)
		if not ok then
			fail("config %s 失败: %s", spec.name, err)
		end
	elseif spec.config == true or has_opts then
		local main = resolve_main(spec, plugin.dir)
		if not main then
			fail("无法推断 %s 的主模块，请显式设置 main 或直接写 config 函数", spec.name)
			return
		end
		local ok, mod = pcall(require, main)
		if not ok then
			fail("require %s 失败 (config %s): %s", main, spec.name, mod)
			return
		end
		if type(mod) == "table" and type(mod.setup) == "function" then
			local ok2, err = pcall(mod.setup, opts)
			if not ok2 then
				fail("setup %s 失败: %s", spec.name, err)
			end
		end
	end
end

local function apply_keys(spec)
	local keys = spec.keys
	if not keys then
		return
	end

	local list
	if type(keys) ~= "table" then
		list = { keys }
	elseif type(keys[1]) == "string" or keys.lhs ~= nil then
		list = { keys }
	else
		list = keys
	end

	for _, k in ipairs(list) do
		local lhs, rhs, mode
		if type(k) == "string" then
			lhs = k
		else
			lhs = k[1] or k.lhs
			rhs = k[2] or k.rhs
			mode = k.mode
			if rhs == nil then
				-- 纯 lhs 条目在 lazy.nvim 里是"分组标签"，在这里只会变成 lhs→lhs 的空映射，
				-- 还会覆盖 config 里定义的真实映射（rustowl 就这么坏过）。分组请写进
				-- lua/plugins/which-key.lua 的 wk.add。
				fail("keys %s: 缺少 rhs，已跳过（分组标签请写进 which-key.lua）", lhs)
				rhs = false
			end
		end
		if lhs and rhs then
			local map_opts = {
				desc = type(k) == "table" and k.desc or nil,
				silent = type(k) == "table" and k.silent or nil,
				expr = type(k) == "table" and k.expr or nil,
				nowait = type(k) == "table" and k.nowait or nil,
				remap = type(k) == "table" and k.remap or nil,
			}
			if not key_owner[lhs] then
				key_owner[lhs] = spec.name
				local ok, err = pcall(vim.keymap.set, mode or "n", lhs, rhs, map_opts)
				if not ok then
					fail("keymap %s (%s) 失败: %s", lhs, spec.name, err)
				end
			end
		end
	end
end

-- 加载分两步：先给整批插件 packadd（只是进 rtp + source plugin/，很便宜），
-- 再按依赖顺序跑 config。这样即使 spec 之间的 dependencies 成环（nvim-dap ⇄
-- nvim-dap-disasm 就是），config 里 require 别的插件也不会踩空。
local function activate_spec(spec)
	local path = pack_path(spec.name)
	local ok, err = pcall(vim.cmd.packadd, { spec.name })
	if not ok then
		fail("packadd %s 失败: %s", spec.name, err)
		return false
	end
	-- 新装的插件先跑 build（此时 plugin/ 已 source，:TSUpdate 之类的命令才存在）
	if fresh[spec.src] then
		run_build(spec)
	end
	source_after_plugin(path)
	return true
end

local function configure_spec(spec)
	local t0 = profile and vim.uv.hrtime() or 0
	run_config(spec, plugin_object(spec))
	apply_keys(spec)
	if profile then
		local ms = (vim.uv.hrtime() - t0) / 1e6
		profile_rows[#profile_rows + 1] = { ms = ms, name = spec.name }
	end
end

--- 加载一批插件（先全部 packadd，再按给定顺序跑 config）
local function load_batch(batch)
	local active = {}
	for _, spec in ipairs(batch) do
		if activate_spec(spec) then
			active[#active + 1] = spec
		end
	end
	for _, spec in ipairs(active) do
		configure_spec(spec)
	end
end

----------------------------------------------------------------------
-- 主流程
----------------------------------------------------------------------

local function main()
	phase("collect+normalize", collect)

	-- 装上还没装的（load = false 等价 :packadd!，只进 rtp 不 source plugin/）
	local to_install = {}
	for _, spec in ipairs(order) do
		if is_enabled(spec) then
			local entry = { src = spec.src, name = spec.name }
			if spec.version then
				entry.version = spec.version
			end
			if not vim.uv.fs_stat(pack_path(spec.name)) then
				fresh[spec.src] = true
				to_install[#to_install + 1] = entry
			end
		else
			spec._disabled = true
		end
	end

	if #to_install > 0 then
		local ok, err = phase("vim.pack.add", pcall, vim.pack.add, to_install, { confirm = false, load = false })
		if not ok then
			fail("vim.pack.add 失败: %s", err)
			return
		end
	end

	-- 依赖优先 + priority 降序（colorscheme 这类要最先）
	local loaded, visiting = {}, {}
	local load_order = {}

	local function visit(spec)
		if loaded[spec.src] or visiting[spec.src] or spec._disabled then
			return
		end
		visiting[spec.src] = true
		local deps = vim.deepcopy(spec._deps or {})
		table.sort(deps, function(a, b)
			if priority_of(a) ~= priority_of(b) then
				return priority_of(a) > priority_of(b)
			end
			return (a._order or 0) < (b._order or 0)
		end)
		for _, dep in ipairs(deps) do
			visit(dep)
		end
		visiting[spec.src] = nil
		loaded[spec.src] = true
		load_order[#load_order + 1] = spec
	end

	local roots = vim.deepcopy(order)
	table.sort(roots, function(a, b)
		if priority_of(a) ~= priority_of(b) then
			return priority_of(a) > priority_of(b)
		end
		return (a._order or 0) < (b._order or 0)
	end)
	for _, spec in ipairs(roots) do
		visit(spec)
	end

	-- init 先全部跑一遍（lazy.nvim 语义：init 在插件加载前，用于设置 vim.g）
	phase("run_init", function()
		for _, spec in ipairs(load_order) do
			run_init(spec)
		end
	end)

	local defer = should_defer()
	local now, later = {}, {}
	for _, spec in ipairs(load_order) do
		if defer and deferred[spec.name] then
			later[#later + 1] = spec
		else
			now[#now + 1] = spec
		end
	end

	phase("wave1", load_batch, now)

	if #later > 0 then
		-- 分块加载：每块之后让出一次事件循环，避免首帧之后突然卡住 200ms
		local CHUNK = 4
		local function load_chunk(from)
			-- 已经在退出（:wq 等）就别再加载插件了，否则弹窗会卡住退出。
			-- 注意 vim.v.exiting 返回的是 Float，用数值比较前先转一下。
			if (tonumber(vim.v.exiting) or 0) > 0 then
				return
			end
			local last = math.min(from + CHUNK - 1, #later)
			load_batch(vim.list_slice(later, from, last))
			if last < #later then
				vim.schedule(function()
					load_chunk(last + 1)
				end)
			else
				report_errors()
			end
		end

		vim.api.nvim_create_autocmd("VimEnter", {
			once = true,
			callback = function()
				vim.schedule(function()
					load_chunk(1)
				end)
			end,
			desc = "首帧之后再加载重插件（见 pack.lua 的 DEFER_HEAVY）",
		})
	end

	if profile then
		table.sort(profile_rows, function(a, b)
			return a.ms > b.ms
		end)
		local total = 0
		for _, row in ipairs(profile_rows) do
			total = total + row.ms
		end
		local lines = { ("插件加载总耗时 %.1fms（%d 个）"):format(total, #profile_rows) }
		for _, row in ipairs(phase_rows) do
			lines[#lines + 1] = ("阶段 %6.1fms  %s"):format(row.ms, row.name)
		end
		for i = 1, math.min(25, #profile_rows) do
			lines[#lines + 1] = ("  %6.1fms  %s"):format(profile_rows[i].ms, profile_rows[i].name)
		end
		io.stderr:write(table.concat(lines, "\n") .. "\n")
	end

	report_errors()
end

main()

----------------------------------------------------------------------
-- 用户命令：原生 :packupdate / :packdel 之外的薄封装
----------------------------------------------------------------------

vim.api.nvim_create_user_command("PackUpdate", function(cmd)
	vim.cmd("packupdate" .. (cmd.bang and "!" or ""))
end, { desc = "更新所有插件（原生 vim.pack）", bang = true })

vim.api.nvim_create_user_command("PackStatus", function()
	local packs = vim.pack.get()
	vim.notify(("已注册 %d 个插件"):format(#packs), vim.log.levels.INFO)
end, { desc = "查看插件数量" })

-- dir = "~/neovim-plugins/*" 的本地插件：vim.pack 会 clone 一份副本，
-- 改为手动触发同步（<leader>zp 或 :PackLocalSync），不阻塞启动。
require("core.pack_local").setup()

---当前加载器收集到的 spec（调试用）
---@return table<string, table>
function M.specs()
	return by_src
end

return M
