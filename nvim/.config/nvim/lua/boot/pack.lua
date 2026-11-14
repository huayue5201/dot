-- 插件管理：安装 / 更新 / 锁文件 / 版本全部交给 Neovim 自带的 vim.pack。
-- 加载策略是「全 eager」：启动时把所有插件都激活（进 rtp + source plugin/）并跑 config，
-- 不使用任何懒加载代理。唯一例外是「第二波」（见下面的 deferred 表）：少数重插件的
-- config 推到首帧之后再跑。插件本身仍然在启动时激活完毕，命令/require 立即可用，
-- 但它们在 spec 里声明的 keys 是跟着 config 一起装的，所以同样要等到第二波。
--
-- 为什么不再用 zpack：它的 cmd / keys / module 代理会引入一类很难查的 bug
-- （首次按键只加载不执行、命令代理丢 register/range、module 懒加载走 :packadd!
-- 不 source plugin/ 于是命令根本不存在）。eager 之后这些问题从根上不存在。
--
-- spec 写在 lua/plugins/ 下，沿用 lazy.nvim 的写法（旧的懒加载字段已清理干净）：
--   * 分类子目录只是给人看的标签（ai / lsp / dap / git / ui / editor / lang / tools），
--     加载器递归扫描，插件的 find/dir 行为不受影响；清单见 lua/plugins/README.md
--   * 生效的字段：src(第 1 位) / dir / url / name / main / version / branch / tag
--                / sem_version / dependencies / init / config / opts / build / priority / enabled
--   * keys：注册成普通映射（不要写纯 lhs 的分组标签，那会变成空映射）
--            单条 key 支持 lazy.nvim 的 `ft`（string 或 string[]）：写了 ft 的键位不再全局
--            注册，而是在 FileType 命中时建成 buffer-local，这样「只对某种语言有意义」的
--            键位不会在别的 buffer 里变成噪音（which-key 也只在对应 buffer 显示）。
--   * 不识别（写了也无效）：event / cmd / module / lazy

local M = {}

local config_dir = vim.fn.stdpath("config")
local spec_dir = vim.fs.joinpath(config_dir, "lua", "plugins")

-- 锁文件放到 data 目录，避免污染配置仓库。必须在第一次 vim.pack 调用之前设置。
if vim.fn.exists("+packlockfile") == 1 then
	vim.o.packlockfile = vim.fs.joinpath(vim.fn.stdpath("data"), "nvim-pack-lock.json")
end

local errors = {}
local had_errors = false -- 本次会话是否报过错（prune 门禁用，errors 报完就清）

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

-- 本次启动新装的插件（name 集合）：只有它们需要跑 build
local fresh = {}

local function fail(fmt, ...)
	had_errors = true
	errors[#errors + 1] = fmt:format(...)
end

local function report_errors()
	if #errors == 0 then
		return
	end
	local msg = table.concat(errors, "\n")
	errors = {} -- 清空：否则同一批错误会在每轮 report_errors 里重复弹（reload 时还会把启动期的旧错误再报一遍）
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

--- spec 里的版本约束统一成 vim.pack 的 version 字段（branch / tag 单独放着也行，
--- 取第一个有值的；三者互斥，语义见 lua/plugins/*.lua 的注释）
local function normalize_version(spec)
	if spec.version ~= nil then
		return spec.version
	end
	if spec.sem_version then
		return vim.version.range(spec.sem_version)
	end
	return spec.branch or spec.tag
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
		-- 本地目录（dir = "~/neovim-plugins/x"）直接进 rtp，不交给 vim.pack：
		-- clone 副本 + 锁文件 rev 会让「改完代码重启就好」变成「commit + 同步 + 重启」，
		-- 而且忘了同步时加载的还是旧代码。dev 插件本来就该读工作区。
		spec._dev = true
	elseif not is_git_url(source) then
		src = "https://github.com/" .. source
	end

	spec[1] = nil
	spec.src = src
	spec.name = name
	spec.version = normalize_version(spec)
	spec._order = order
	-- 归一化一次，加载排序就不用每次比较都现算（priority 是静态字段）
	spec._priority = type(spec.priority) == "number" and spec.priority or 50
	if spec.enabled == false then
		spec._disabled = true
	end

	return spec
end

local by_name = {} -- name -> spec（vim.pack 的安装目录就是 name，同名只能有一份）
local by_src = {} -- src -> spec（热重载按 src 找 spec）
local order = {}

--- 同名插件只留一份：dependency 里写 "igorlfs/nvim-dap-view"、另处又用 dir 指向本地工作区时，
--- 两份各自装一遍，副本就会出现在 opt 里（删掉下次启动还会被 vim.pack 按锁文件造回来）。
--- 本地 fork 优先，其余字段「先到先得 + dependencies 追加」；冲突的标量字段报出来。
local CONFLICT_FIELDS = { "enabled", "priority", "main", "version", "build" }
local function register(spec)
	if not spec then
		return nil
	end
	local existing = by_name[spec.name]
	if not existing then
		spec._order = #order + 1 -- 单调递增：同 priority 下的排序才稳定
		by_name[spec.name] = spec
		by_src[spec.src] = spec
		order[#order + 1] = spec
		return spec
	end
	if spec._dev and not existing._dev then
		by_src[existing.src] = nil -- 换了 src，旧键不留（reload_spec 会按它误命中）
		existing.src = spec.src
		existing.dir = spec.dir
		existing._dev = true
		by_src[existing.src] = existing
	end
	for k, v in pairs(spec) do
		if k == "dependencies" then
			existing.dependencies = existing.dependencies or {}
			vim.list_extend(existing.dependencies, v)
		elseif k ~= "src" and k ~= "dir" and k ~= "_dev" and existing[k] == nil then
			existing[k] = v
		elseif existing[k] ~= v and vim.tbl_contains(CONFLICT_FIELDS, k) then
			fail(
				"spec %s 的 %s 声明了两次且不同（%s → %s），已用第一份",
				spec.name,
				k,
				tostring(existing[k]),
				tostring(v)
			)
		end
	end
	by_src[spec.src] = existing
	return existing
end

-- 一个 spec 文件可能返回「单个 spec」或「spec 列表」。判定依据：
--   * 第 1 位是字符串 → 单个 spec（仓库名就写在 [1]）
--   * 第 1 位是表   → spec 列表
--   * 没有第 1 位   → 顶层出现已知 spec 字段即为单个 spec（本地 fork 只写 dir/name 的情况）
-- 这一步不能搞错：把「单个 spec」当成列表遍历，只会取到 [1] 那个仓库名字符串，
-- 整个 spec 的 dependencies / config / keys 全部丢失。
local SPEC_FIELDS = {
	"dir",
	"src",
	"url",
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
	"sem_version",
	"priority",
	"enabled",
	"keys",
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

--- spec 目录下的全部 spec 文件，支持任意层级的分类子目录（lua/plugins/<类>/<插件>.lua）。
---
--- 目录名只是给人看的标签，不参与加载排序：仍按「文件名」排序，因此 priority
--- 相同时的声明次序与全部平铺时代完全一致（路径仅作同名文件的次级排序键）。
--- 例外：某目录下存在 init.lua 时，该目录本身视为一个 spec 模块（与顶层一致），
--- 不再递归进去，避免把它的内部辅助 lua 文件误当 spec。
---
--- lua/feat/config_reload.lua 也走这里（它需要同一份文件清单），所以导出而不是留在
--- collect 内部，避免两套递归实现各自漂移。
---@return string[] relpaths, string dir
function M.spec_files()
	local files = {}
	---@param rel string 相对 spec_dir 的子目录（"" 表示根）
	local function walk(rel)
		local dir = rel == "" and spec_dir or vim.fs.joinpath(spec_dir, rel)
		for entry, kind in vim.fs.dir(dir) do
			local relpath = rel == "" and entry or (rel .. "/" .. entry)
			if kind == "file" and entry:match("%.lua$") then
				-- init.lua 是包入口/辅助，不是 spec
				if entry ~= "init.lua" then
					files[#files + 1] = relpath
				end
			elseif kind == "directory" then
				if vim.fn.filereadable(vim.fs.joinpath(spec_dir, relpath, "init.lua")) == 1 then
					files[#files + 1] = relpath
				else
					walk(relpath)
				end
			end
		end
	end
	walk("")
	table.sort(files, function(a, b)
		local an, bn = a:match("[^/]+$"), b:match("[^/]+$")
		if an ~= bn then
			return an < bn
		end
		return a < b
	end)
	return files, spec_dir
end

--- 收集 spec 模块并归一化
local function collect()
	for i, file in ipairs(M.spec_files()) do
		local mod = "plugins." .. file:gsub("%.lua$", ""):gsub("/", ".")
		local ok, ret = pcall(require, mod)
		if not ok then
			fail("spec %s 加载失败: %s", mod, ret)
		elseif type(ret) ~= "table" then
			-- 条件禁用写成 `if not x then return end` 会落到这里：不报的话插件根本没声明，
			-- 启动期 prune 还会把它目录删掉
			fail("spec %s 返回了 %s（需要 table）", mod, type(ret))
		else
			local single = is_single_spec(ret)
			if not single and next(ret) ~= nil and ret[1] == nil then
				-- 顶层字段一个都不认识（写了不支持的键名）：静默丢弃是最坏的结果
				fail("spec %s 既不像单个 spec 也不像列表（字段: %s）", mod, table.concat(vim.tbl_keys(ret), ","))
			else
				local items = single and { ret } or ret
				-- 用 pairs+排序而不是 ipairs：列表里出现 nil 洞（条件禁用写成
				-- nil 条目）时 ipairs 会在洞处截断，后面的 spec 全部丢失
				local idx = {}
				for kk in pairs(items) do
					if type(kk) == "number" then
						idx[#idx + 1] = kk
					end
				end
				table.sort(idx)
				for _, kk in ipairs(idx) do
					register(normalize_spec(items[kk], i))
				end
			end
		end
	end

	-- 展开 dependencies（字符串 / 内联 spec 都可以），并记录边。
	-- 合并同名 spec 时可能给对方追加 dependencies，所以跑到不动点（通常 1 轮就停）。
	for _ = 1, 5 do
		local changed = false
		local i = 1
		while i <= #order do
			local spec = order[i]
			local list = spec.dependencies
			local deps = {}
			if list then
				list = type(list) == "table" and list or { list }
				for _, dep in ipairs(list) do
					local dep_spec = register(normalize_spec(dep, spec._order))
					if dep_spec then
						deps[#deps + 1] = dep_spec
					end
				end
			end
			if #deps ~= #(spec._deps or {}) then
				changed = true
			end
			spec._deps = deps
			i = i + 1
		end
		if not changed then
			break
		end
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
local deferred = {
	["obsidian.nvim"] = true,
	["codecompanion.nvim"] = true,
	["treesj"] = true,
	["neotest"] = true,
	["codediff.nvim"] = true,
	["diffbandit.nvim"] = true,
	["neogit"] = true,
	["atlas.nvim"] = true,
	["cash.nvim"] = true,
	["nurl.nvim"] = true,
	["crates.nvim"] = true,
	-- 调试链路：不开始调试就完全用不到（statusline 的 dap 段自己会判断
	-- package.loaded["dap"]，见 lua/ui/statusline.lua 的 dap()）
	["nvim-dap"] = true,
	["nvim-dap-view"] = true,
	["nvim-dap-cortex-debug"] = true,
	["nvim-dap-image"] = true,
	["nvim-dap-python"] = true,
	["nvim-dap-go"] = true,
	["crazy-coverage.nvim"] = true,
	["nvim-dev-container"] = true,
	["mason.nvim"] = true,
	-- 只在特定 buffer/事件里生效的工具，setup 晚一点不影响（裸启动时没有 buffer）
	["image.nvim"] = true,
	["fidget.nvim"] = true,
	["minuet-ai.nvim"] = true,
	["nvim-chainsaw"] = true,
	["namu.nvim"] = true,
	["focal.nvim"] = true,
	["nvim-translator"] = true,
	["overseer.nvim"] = true,
	["nvim-origami"] = true,
	["nvim-hlslens"] = true,
	["tiny-inline-diagnostic.nvim"] = true,
}

local function should_defer()
	if vim.env.NVIM_PACK_EAGER == "1" then
		return false -- 调试/脚本：强制全 eager
	end
	-- 开了文件就必须 eager：它的 FileType 在 VimEnter 之前就触发，延后等于插件没生效。
	-- 这条要排在 NVIM_PACK_DEFER 之前（调试开关不该绕过正确性）
	if vim.fn.argc() > 0 then
		return false
	end
	if vim.env.NVIM_PACK_DEFER == "1" then
		return true -- 调试：强制延后
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

--- priority 降序；同 priority 按声明的 spec 文件顺序，保证加载次序稳定可复现
local function by_priority(a, b)
	if a._priority ~= b._priority then
		return a._priority > b._priority
	end
	return (a._order or 0) < (b._order or 0)
end

--- vim.pack 的克隆副本根目录（本地 dev 插件直接读工作区，不走这里）
local pack_root = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt")

local function pack_path(name)
	return vim.fs.joinpath(pack_root, name)
end

--- 插件在磁盘上的目录：dev 插件读工作区，其余读 vim.pack 的克隆副本
---@param spec table
---@return string
local function plugin_dir(spec)
	return spec._dev and spec.src or pack_path(spec.name)
end

-- :packadd 做两件事：把插件目录插进 'runtimepath'（位置在 packpath 的
-- <data>/site 那一项之后，后加入的排在更前面），再 source 它的 plugin/**。
-- 这里把两件事拆开自己做：104 个插件逐个 :packadd 共 65ms，主要是每条 Ex 命令的
-- 解析与 runtime! 搜索；一次性赋值 rtp + 自己 glob source 大约 12ms。
-- 顺序必须和 packadd 完全一致，否则同名 runtime 文件（两个 plugin 都带
-- ftplugin/rust.lua 之类）的优先级会变，所以插入位置与逆序规则照抄。
-- 插件目录插在 <data>/site 之后；若插件带 after/ 目录，还要把它插到「after 段」的
-- 开头（packadd 的两个动作，rtp 里实测验证过）。两处都是后加载的排在前面。
local function enter_rtp(paths)
	local site = vim.fs.joinpath(vim.fn.stdpath("data"), "site")
	-- 用选项的 list 形式取/写：路径里含逗号时 vim.o.runtimepath 的逗号转义会被
	-- 手写 split/concat 拆坏
	local ps = vim.opt.runtimepath:get()
	local idx
	for i, p in ipairs(ps) do
		if p == site then
			idx = i
			break
		end
	end
	if not idx then
		return false
	end
	local seen = {}
	for _, p in ipairs(ps) do
		seen[p] = true
	end
	local head, tail = {}, {}
	for i = 1, idx do
		head[i] = ps[i]
	end
	for i = idx + 1, #ps do
		tail[#tail + 1] = ps[i]
	end
	for i = #paths, 1, -1 do
		local p = paths[i]
		if not seen[p] then
			seen[p] = true
			head[#head + 1] = p
		end
	end
	-- added == 0 时也继续处理 after/：两者是独立的两件事，一起跳过会让 after/ 变成半死代码
	-- after 段起点：第一个以 /after 结尾的项
	local after_at
	for i, p in ipairs(tail) do
		if p:sub(-6) == "/after" then
			after_at = i
			break
		end
	end
	local afters = {}
	for i = #paths, 1, -1 do
		local p = paths[i] .. "/after"
		if not seen[p] and vim.uv.fs_stat(p) then
			seen[p] = true
			afters[#afters + 1] = p
		end
	end
	if #afters > 0 then
		local at = after_at or (#tail + 1)
		for i = #afters, 1, -1 do
			table.insert(tail, at, afters[i])
		end
	end
	vim.opt.runtimepath = vim.list_extend(head, tail)
	return true
end

--- source 一个 plugin/ 或 after/plugin 目录下的全部文件（先 .vim 后 .lua，与 :packadd 顺序一致）。
--- 目录不存在就直接返回：绝大多数插件没有 after/plugin，省掉两次 glob。
local function source_dir(dir)
	if not vim.uv.fs_stat(dir) then
		return
	end
	for _, ext in ipairs({ "vim", "lua" }) do
		for _, file in ipairs(vim.fn.glob(dir .. "/**/*." .. ext, false, true)) do
			local ok, err = pcall(vim.cmd.source, file)
			if not ok then
				fail("source %s 失败: %s", file, err)
			end
		end
	end
end

-- "obsidian.nvim" / "nvim-chainsaw" 这类仓库名并不是 Lua 模块名，
-- 去掉 nvim 前后缀与标点后再比较（仓库名 → Lua 模块名的常见约定）。
local function normalize_mod_name(name)
	return (name:lower():gsub("^n?vim%-", ""):gsub("%.n?vim$", ""):gsub("[%.%-_]", ""))
end

-- 多个 spec 声明同一个 lhs + mode + ft 集合时，第一个生效，避免互相覆盖后找不到来源。
-- id -> { owner = spec.name }：全局键与 ft 键都走 key_id()。
local key_owner = {}

--- mode 也是身份的一部分：同一 lhs 在 n / x 下是两个独立映射
--- （如 assembly 的 <leader>ra：normal 看函数、visual 走 :Asm 选区）。
--- mode 可以是字符串或字符串数组（lazy.nvim 写法），统一成排序后的逗号串做 id
local function mode_id(k)
	local m = k.mode or "n"
	if type(m) == "table" then
		local t = vim.deepcopy(m)
		table.sort(t)
		return table.concat(t, ",")
	end
	return m
end

---@param k table
---@param ft_list? string[]
---@return string
local function key_id(k, ft_list)
	local mode = mode_id(k)
	if not ft_list then
		return "g:" .. mode .. "|" .. k[1]
	end
	local fts = vim.deepcopy(ft_list)
	table.sort(fts)
	return "ft:" .. mode .. "|" .. k[1] .. "|" .. table.concat(fts, ",")
end

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

--- 传给 init / build / config / opts 的 plugin 对象。只给 spec 文件真正用得上的两个字段
--- （lazy.nvim 那套 path / spec / dependencies 没有任何 spec 用，不复制）
local function plugin_object(spec)
	return { name = spec.name, dir = plugin_dir(spec) }
end

----------------------------------------------------------------------
-- 各阶段：build / init / load(config, keys)
----------------------------------------------------------------------

--- 在插件目录里跑 build（lazy.nvim 的语义：cwd = 插件根目录）
local function run_build(spec)
	local build = spec.build
	if not build then
		return true
	end
	local dir = plugin_dir(spec)
	local cwd = vim.fn.getcwd()
	-- cd 失败不能静默：否则 build 跑在用户当前目录，产物散落到项目里
	if vim.uv.fs_stat(dir) and not pcall(vim.cmd, "cd " .. vim.fn.fnameescape(dir)) then
		fail("build %s: 无法进入 %s，build 将在当前目录执行", spec.name, dir)
	end
	local ok, err
	if type(build) == "function" then
		ok, err = pcall(build, plugin_object(spec))
	elseif type(build) == "string" then
		ok, err = pcall(vim.cmd, (build:gsub("^%s*:%%?", "")))
	else
		-- lazy.nvim 风格的 { "cmd", "arg" } 之类：以前什么都没跑，还静默算成功
		fail("build %s: 不支持的类型 %s（需要 function 或 string）", spec.name, type(build))
		ok = false
		err = "unsupported build type"
	end
	if vim.fn.getcwd() ~= cwd then
		pcall(vim.cmd, "cd " .. vim.fn.fnameescape(cwd))
	end
	if not ok then
		fail("build %s 失败: %s", spec.name, err)
		return false
	end
	return true
end

----------------------------------------------------------------------
-- build 产物与源版本的一致性
--
-- vim.pack 只换文件、不跑 build（:Pack update 统一这样），所以
-- 有 build 字段的插件只要源 rev 变了，产物就是旧的（nvim-translator 的 Rust
-- 二进制就因此和 lua 不同步）。这里记录「每个插件上一次 build 成功的 rev」，
-- 启动时发现 rev 变了就补一次 build。
----------------------------------------------------------------------

local built_stamp = vim.fs.joinpath(vim.fn.stdpath("data"), "pack-built.json")

---@param dir string
---@return string|nil rev
local function git_rev(dir)
	if not vim.uv.fs_stat(dir) then
		return nil
	end
	local ok, out = pcall(function()
		return vim.system({ "git", "-C", dir, "rev-parse", "HEAD" }, { text = true }):wait(2000)
	end)
	if not ok or not out or out.code ~= 0 then
		return nil
	end
	local rev = vim.trim(out.stdout or "")
	return rev ~= "" and rev or nil
end

local built
local built_dirty = false
---第一次运行（还没有 stamp 文件）：不做任何重建，只把当前 rev 记成基线，
---避免升级到这套机制时把所有 build 插件（含 :TSUpdate）全部重跑一遍。
local built_missing = false

---@return table<string, string> name -> rev
--- 直接读锁文件，不用 vim.pack.get：后者会走 lock_sync，对「锁里有、目录没了」的
--- 条目先 clone 回来（confirm=true 时还会弹模态框），prune 会先复原再删除，白费一次网络
--- 还可能和用户的选择打架。
---@return table<string, { src: string?, rev: string? }>
local function lock_plugins()
	local ok, lines = pcall(vim.fn.readfile, vim.go.packlockfile)
	if not ok or type(lines) ~= "table" then
		return {}
	end
	local okj, data = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not okj or type(data) ~= "table" or type(data.plugins) ~= "table" then
		return {}
	end
	return data.plugins
end

--- 记账用的「源标识」：rev + dev 标记 + 工作区是否脏。
--- 只用 name 当键时，dev fork 与远端版共用一条记录；dev 不改 commit 时
--- (改了代码没提交) rev 不变，build 就永远不会重跑。
local function build_stamp_of(spec)
	local rev = git_rev(plugin_dir(spec))
	if not rev then
		return nil
	end
	if not spec._dev then
		return rev
	end
	local ok, out = pcall(function()
		return vim.system(
			{ "git", "-C", plugin_dir(spec), "status", "--porcelain", "--", "." },
			{ text = true }
		):wait(1000)
	end)
	local dirty = ok and out and out.code == 0 and vim.trim(out.stdout or "") ~= ""
	return rev .. (dirty and "+dirty" or "")
end

local function read_built()
	if built then
		return built
	end
	built = {}
	local ok, lines = pcall(vim.fn.readfile, built_stamp)
	if ok and type(lines) == "table" and #lines > 0 then
		local okj, data = pcall(vim.json.decode, table.concat(lines, "\n"))
		if okj and type(data) == "table" then
			built = data
			return built
		end
	end
	built_missing = true
	return built
end

---记录某个插件当前 rev 已构建成功（只标脏，落盘统一由 flush_built 做）
local function record_built(spec)
	local rev = build_stamp_of(spec)
	if not rev then
		return
	end
	read_built()[spec.name] = rev
	built_dirty = true
end

local function run_init(spec)
	if type(spec.init) == "function" then
		local ok, err = pcall(spec.init, plugin_object(spec))
		if not ok then
			fail("init %s 失败: %s", spec.name, err)
		end
	end
end

local function run_config(spec, plugin)
	local opts = type(spec.opts) == "table" and spec.opts or {}

	if type(spec.config) == "function" then
		local ok, err = pcall(spec.config, plugin, opts)
		if not ok then
			fail("config %s 失败: %s", spec.name, err)
		end
	elseif spec.config == true or spec.opts ~= nil then
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

--- keys 既可以写成列表，也可以写成单个 { lhs, rhs, ... }
---
--- 单条 key 可带 `ft`（string | string[]）：只在这些 filetype 的 buffer 里注册（buffer-local），
--- 等价于 lazy.nvim 的 keys[].ft。用于「只在某种语言里才有意义」的键位，避免全局噪音。
local ft_pending = {} -- { { fts = { [ft] = true }, entry = k, spec = name } }
local ft_autocmd_ready = false

local function key_opts(k, buf)
	local opts = {
		desc = k.desc,
		silent = k.silent,
		expr = k.expr,
		nowait = k.nowait,
		remap = k.remap,
	}
	if buf then
		opts.buffer = buf
	end
	return opts
end

local function set_key(spec_name, k, lhs, rhs, buf)
	local ok, err = pcall(vim.keymap.set, k.mode or "n", lhs, rhs, key_opts(k, buf))
	if not ok then
		fail("keymap %s (%s) 失败: %s", lhs, spec_name, err)
	end
end

local function install_ft_keys(buf)
	local ft = vim.bo[buf].filetype
	for _, item in ipairs(ft_pending) do
		if item.fts[ft] then
			set_key(item.spec, item.entry, item.entry[1], item.entry[2], buf)
		end
	end
end

--- 启动时已经打开的 buffer（FileType 早就触发过，等不到 autocmd）补装一次。
--- 只在一批 spec 全部登记完之后跑：每登记一个键就全量扫一遍 buffer 是白做 N 倍。
local function backfill_ft_keys()
	if #ft_pending == 0 then
		return
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			install_ft_keys(buf)
		end
	end
end

local function ensure_ft_autocmd()
	if ft_autocmd_ready then
		return
	end
	ft_autocmd_ready = true
	local group = vim.api.nvim_create_augroup("pack_ft_keys", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		callback = function(event)
			install_ft_keys(event.buf)
		end,
	})
end

local function register_ft_key(spec, k, ft_list)
	local id = key_id(k, ft_list)
	if key_owner[id] then
		return -- 同 lhs + 同 ft 集合只登记一次
	end
	key_owner[id] = { owner = spec.name }
	local fts = {}
	for _, ft in ipairs(ft_list) do
		fts[ft] = true
	end
	ft_pending[#ft_pending + 1] = { fts = fts, entry = k, spec = spec.name }
	ensure_ft_autocmd()
end

local function apply_keys(spec)
	local keys = spec.keys
	-- keys = {} 会被下面包成 { {} } 然后报一条「缺少 lhs/rhs」的假错误
	if not keys or (type(keys) == "table" and next(keys) == nil) then
		return
	end

	for _, k in ipairs(type(keys[1]) == "table" and keys or { keys }) do
		local lhs, rhs = k[1], k[2]
		local fts = type(k.ft) == "string" and { k.ft } or k.ft
		if type(lhs) ~= "string" or rhs == nil then
			-- 纯 lhs 条目在 lazy.nvim 里是"分组标签"，在这里只会变成 lhs→lhs 的空映射，
			-- 还会覆盖 config 里定义的真实映射（rustowl 就这么坏过）。分组请写进
			-- lua/plugins/ui/which-key.lua 的 wk.add。
			fail("keys %s: 缺少 lhs/rhs，已跳过（分组标签请写进 which-key.lua）", tostring(lhs))
		elseif type(fts) == "table" then
			register_ft_key(spec, k, fts)
		else
			local id = key_id(k, nil)
			if not key_owner[id] then
				key_owner[id] = { owner = spec.name }
				set_key(spec.name, k, lhs, rhs)
			end
		end
	end
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

--- rev 变了（或从未记录过）说明产物可能是旧的
---@return boolean

local function stale_build(spec)
	if not spec.build then
		return false
	end
	local rev = build_stamp_of(spec)
	if not rev then
		return false
	end
	local data = read_built()
	if built_missing then
		-- 基线：认为磁盘上的产物与当前源一致，只记录下来（统一在 flush_built 落盘）。
		data[spec.name] = rev
		built_dirty = true
		return false
	end
	return data[spec.name] ~= rev
end

---把基线 / 重建结果写回 stamp 文件（每批插件跑完一次，避免逐个写盘）
local function flush_built()
	if not built_dirty then
		return
	end
	local ok = pcall(vim.fn.writefile, { vim.json.encode(read_built()) }, built_stamp)
	if ok then
		built_dirty = false
	else
		fail("写 %s 失败：每次启动都会重建已构建的插件", built_stamp)
	end
end

--- build 成功后记账：全文件唯一的「跑 build + 记 rev」入口
local function build_and_record(spec)
	if run_build(spec) then
		record_built(spec)
		return true
	end
	return false
end

--- 本地 dir 插件的 build 一般很快（cargo/make 已经很干净时是空转），直接同步跑，
--- 保证本进程里立刻就有新产物；远程插件可能很重（:TSUpdate、下载二进制），推到
--- 启动完成之后跑，避免卡启动。
local function rebuild_now(spec)
	if spec._dev then
		build_and_record(spec)
		return
	end
	vim.schedule(function()
		build_and_record(spec)
		flush_built()
		report_errors()
	end)
end

---helptags 的产物不该让第三方仓库变脏。vim.pack 每次 checkout 都会删掉 doc/tags
---再 `:helptags` 重新生成，但仓库通常没忽略它：于是每个插件都多出「未跟踪文件」，
---下一次 `git checkout` 若目标提交里有这个文件就直接失败（bufferline.nvim 的副本
---就是这样每次都更新失败）。写进仓库自己的 .git/info/exclude（不进版本库、也不改
---上游文件）一次就永久生效。
---@param dir string
local function ignore_generated_tags(dir)
	local exclude = dir .. "/.git/info/exclude"
	if vim.uv.fs_stat(exclude) == nil then
		return -- 不是 git clone（dev 插件读的是用户自己的工作区，不去动）
	end
	local ok, lines = pcall(vim.fn.readfile, exclude)
	if not ok or type(lines) ~= "table" then
		return
	end
	for _, l in ipairs(lines) do
		if l == "doc/tags" then
			return
		end
	end
	lines[#lines + 1] = "doc/tags"
	pcall(vim.fn.writefile, lines, exclude)
end

--- 只激活（进 rtp + source plugin/ + 跑 build），不跑 config
local function activate_batch(batch)
	local paths = {}
	for i, spec in ipairs(batch) do
		paths[i] = plugin_dir(spec)
	end
	-- enter_rtp 失败 = rtp 里找不到 packpath 的 site 项（非常规环境），退回逐个 :packadd。
	-- :packadd 自己会 source plugin/，所以这条分支不再调 source_dir。
	local via_packadd = not enter_rtp(paths)
	for i, spec in ipairs(batch) do
		if via_packadd then
			-- 退回 :packadd 时 dev 插件不在 pack 里，自己插 rtp + source plugin/
			if spec._dev then
				-- append 而不是 prepend：prepend 会让 dev 插件抢到最高优先级，
				-- 而且倒序遍历时相对顺序也反了
				vim.opt.runtimepath:append(paths[i])
				source_dir(paths[i] .. "/plugin")
			else
				local ok, err = pcall(vim.cmd.packadd, { spec.name })
				if not ok then
					fail("packadd %s 失败: %s", spec.name, err)
				end
			end
		else
			source_dir(paths[i] .. "/plugin")
			if not spec._dev then
				ignore_generated_tags(paths[i])
			end
		end
		-- 新装的插件先跑 build（此时 plugin/ 已 source，:TSUpdate 之类的命令才存在）。
		-- 但 :TSUpdate / jieba 安装这类要几十秒，别卡住首屏：延后到启动完成后跑
		-- （build 不是加载的前置条件，插件本身已经能用了）
		if fresh[spec.name] then
			vim.schedule(function()
				build_and_record(spec)
				flush_built()
				report_errors()
			end)
		elseif stale_build(spec) then
			rebuild_now(spec)
		end
		source_dir(paths[i] .. "/after/plugin")
	end
	flush_built()
end

--- 加载一批插件，分三步：① 整批进 rtp + source plugin/（源与 :packadd 等价，但一次赋值
--- 搞定），② 新装的插件跑 build，③ 按给定顺序跑 config。这样即使 spec 之间的 dependencies
--- 成环（nvim-dap ⇄ nvim-dap-disasm 就是），config 里 require 别的插件也不会踩空。
local function load_batch(batch)
	if #batch == 0 then
		return
	end
	activate_batch(batch)
	for _, spec in ipairs(batch) do
		configure_spec(spec)
	end
end

----------------------------------------------------------------------
-- 主流程
----------------------------------------------------------------------

local function main()
	phase("collect+normalize", collect)

	-- 装上还没装的（load = false 等价 :packadd!，只进 rtp 不 source plugin/）
	-- dev 插件（src 是本地目录）不装：直接读工作区，没有副本要同步
	local locked = lock_plugins()
	local to_install = {}
	for _, spec in ipairs(order) do
		if not spec._disabled and not spec._dev then
			local entry = { src = spec.src, name = spec.name }
			if spec.version then
				entry.version = spec.version
			end
			local lock = locked[spec.name]
			-- 目录在但 src 换了（换 fork / 本地 fork 改回上游）也要重装：只看目录存在的话
			-- 会永远用旧 src 的 clone，锁文件也还是旧 src，:Pack update 也修不回来
			if not vim.uv.fs_stat(pack_path(spec.name)) or (lock and lock.src ~= nil and lock.src ~= spec.src) then
				fresh[spec.name] = true
				to_install[#to_install + 1] = entry
			end
		end
	end

	if #to_install > 0 then
		if not vim.pack then
			fail("需要 Neovim 0.12+（本版没有 vim.pack）")
			return
		end
		local ok, err = phase("vim.pack.add", pcall, vim.pack.add, to_install, { confirm = false, load = false })
		if not ok then
			-- 不能 return：已装好的插件仍该进 rtp，而且错误必须看得见
			fail("vim.pack.add 失败: %s", err)
			report_errors()
		end
		-- add（:packadd!）把新装插件塞在 site 之后的最前面，顺序和 priority 无关；
		-- 先摘掉，下面 activate_batch 会按排序重新插
		for _, spec in ipairs(order) do
			if fresh[spec.name] and not spec._dev then
				vim.opt.runtimepath:remove(pack_path(spec.name))
				vim.opt.runtimepath:remove(pack_path(spec.name) .. "/after")
			end
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
		table.sort(deps, by_priority)
		for _, dep in ipairs(deps) do
			visit(dep)
		end
		visiting[spec.src] = nil
		loaded[spec.src] = true
		load_order[#load_order + 1] = spec
	end

	local roots = vim.deepcopy(order)
	table.sort(roots, by_priority)
	for _, spec in ipairs(roots) do
		visit(spec)
	end

	-- deferred 里写的是插件名：插件改名/删除后这里会静默失效（延后变成不延后，没人发现），
	-- 所以显式对一遍名字，对不上就报出来。
	for name in pairs(deferred) do
		if not by_name[name] then
			fail("deferred 里的 %s 不在本次加载的插件里（改名或已删除？）", name)
		end
	end

	-- init 先全部跑一遍（lazy.nvim 语义：init 在插件加载前，用于设置 vim.g）
	phase("run_init", function()
		for _, spec in ipairs(load_order) do
			run_init(spec)
		end
	end)

	local defer = should_defer()
	-- 传播：依赖被延后的插件自己也必须延后，否则 config 里的 require("dap") 会踩空
	-- （nvim-dap-disasm → nvim-dap 就是这种情况）。依赖关系可能多层，跑到不动为止。
	local postponed = {}
	if defer then
		for name in pairs(deferred) do
			postponed[name] = true
		end
		local changed = true
		while changed do
			changed = false
			for _, spec in ipairs(load_order) do
				if not postponed[spec.name] then
					for _, dep in ipairs(spec._deps or {}) do
						if postponed[dep.name] then
							postponed[spec.name] = true
							changed = true
							break
						end
					end
				end
			end
		end
	end
	local now, later = {}, {}
	for _, spec in ipairs(load_order) do
		if postponed[spec.name] then
			later[#later + 1] = spec
		else
			now[#now + 1] = spec
		end
	end

	phase("wave1", load_batch, now)
	backfill_ft_keys()

	if #later > 0 then
		-- 时间分片加载：每片最多 4ms，然后让出一次事件循环。
		-- 按时间切而不是按个数切，慢插件不会撑出一帧 40ms 的卡顿。
		local SLICE_MS = 4
		local function configure_slice(from)
			-- 已经在退出（:wq 等）就别再加载插件了，否则弹窗会卡住退出。
			-- 注意 vim.v.exiting 返回的是 Float，用数值比较前先转一下。
			if (tonumber(vim.v.exiting) or 0) > 0 then
				return
			end
			local deadline = vim.uv.hrtime() + SLICE_MS * 1e6
			local i = from
			while i <= #later do
				configure_spec(later[i])
				i = i + 1
				if i > #later or vim.uv.hrtime() >= deadline then
					break
				end
			end
			if i <= #later then
				vim.schedule(function()
					configure_slice(i)
				end)
			else
				-- 分片跑完才 backfill：分片续跑是在 vim.schedule 里，提前 backfill 会漏掉
				-- 后续分片登记的 ft 键对应的已打开 buffer
				backfill_ft_keys()
				report_errors()
			end
		end

		local function start_later()
			-- rtp / plugin/ 一次到位（很便宜，而且保证后面每个 config 里 require 别的
			-- 插件模块都能找到），只有 config 分片跑。
			activate_batch(later)
			configure_slice(1)
		end

		if vim.v.vim_did_enter == 1 then
			vim.schedule(start_later)
		else
			vim.api.nvim_create_autocmd("VimEnter", {
				once = true,
				callback = function()
					vim.schedule(start_later)
				end,
				desc = "首帧之后再加载重插件（见 pack.lua 的 deferred）",
			})
		end
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
-- 清理：spec 里删掉的插件，vim.pack 不会自动删目录，这里手动回收
----------------------------------------------------------------------

--- lockfile 里存在、但本次 spec 已不再声明的插件名
--- @return string[]
local function stale_names()
	local declared = {}
	for _, spec in ipairs(order) do
		declared[spec.name] = true
	end
	local names = {}
	for name in pairs(lock_plugins()) do
		-- declared 里的（含 enabled=false 被停用的）都保留目录
		if not declared[name] and vim.uv.fs_stat(pack_path(name)) then
			names[#names + 1] = name
		end
	end
	-- dev 插件（src 是本地目录）读的是工作区，但历史遗留的副本仍被 :packupdate 当普通
	-- 插件去更新：只要工作区里有 build 产物或未跟踪文件，checkout 就被挡住，于是
	-- 「每次更新都是同样的几个插件」。工作区还在就一并回收这份副本。
	for _, spec in ipairs(order) do
		if spec._dev and vim.uv.fs_stat(spec.src) and vim.uv.fs_stat(pack_path(spec.name)) then
			names[#names + 1] = spec.name
		end
	end
	table.sort(names)
	return names
end

local NO_STALE = "没有需要清理的插件"

--- 删除 spec 里已移除的插件目录
--- @param opts? { dry_run?: boolean, force?: boolean, quiet?: boolean }
--- @return string[] names 命中的插件名（dry_run 时未删除）
function M.prune(opts)
	opts = opts or {}
	local names = stale_names()
	if #names == 0 then
		if not opts.quiet then
			vim.notify(NO_STALE, vim.log.levels.INFO)
		end
		return names
	end
	if opts.dry_run then
		return names
	end
	local ok, err = pcall(vim.pack.del, names, { force = opts.force })
	if not opts.quiet then
		if ok then
			vim.notify(
				("已删除 %d 个未使用插件:\n%s"):format(#names, table.concat(names, ", ")),
				vim.log.levels.INFO
			)
		else
			vim.notify("清理插件失败: " .. tostring(err), vim.log.levels.ERROR)
		end
	end
	return names
end

-- 启动时自动清理；NVIM_PACK_NO_PRUNE=1 可关闭。
-- 有 spec 加载/安装错误时一律不清：那时 order 缺的是「没读到」而不是「已删除」，
-- 照常 prune 会把人家目录删掉（改错一个 spec 文件就把插件的 bin/ 和 clone 一起清了）。
if vim.env.NVIM_PACK_NO_PRUNE ~= "1" and not had_errors then
	pcall(M.prune, { quiet = true })
end

----------------------------------------------------------------------
-- 原生 :packupdate / :packdel 已经够用，这里只补原生没有的几件事：
--   :PackStatus 看已注册数量；:PackPrune 回收 spec 里已移除的目录；
--   :PackLocalSync（在 lua/boot/pack_local.lua 里）删掉 vim.pack 时代留下的本地副本。
vim.api.nvim_create_user_command("PackStatus", function()
	vim.notify(("已注册 %d 个插件"):format(#vim.pack.get(nil, { info = false })), vim.log.levels.INFO)
end, { desc = "查看插件数量" })

-- :PackPrune 只列出将要删除的；:PackPrune! 真的删（--force）。
-- 删除结果的通知在 M.prune 里，这里只负责 dry_run 的预览，不重复拼一遍消息。
vim.api.nvim_create_user_command("PackPrune", function(cmd)
	if cmd.bang then
		M.prune({ force = true })
		return
	end
	local names = M.prune({ dry_run = true, quiet = true })
	if #names == 0 then
		vim.notify(NO_STALE, vim.log.levels.INFO)
	else
		vim.notify(
			("将删除 %d 个未使用插件（:PackPrune! 执行）:\n%s"):format(#names, table.concat(names, "\n")),
			vim.log.levels.WARN
		)
	end
end, { desc = "清理 spec 里已移除的插件目录", bang = true })

-- dir = "~/neovim-plugins/*" 的本地插件直接读工作区（见 normalize_spec 的 spec._dev），
-- 没有 clone 副本要同步；:PackLocalSync 只剩清理旧副本这一个用途。
-- （以前这里有个 M.rebuild，全仓无人调用：改完本地插件重启即可，启动路径会自己补 build）

----------------------------------------------------------------------
-- 热重载：改完 spec 不想重启 nvim（<leader>rtR / :ConfigReload）
----------------------------------------------------------------------

--- 重新加载一个 spec 文件，并重跑其中已有插件的 init/config/keys。
---
--- 只是「重跑」，不是「重新安装」：新增/删除插件、改 version/build 仍需重启；
--- 只有 config / opts / init / keys 这类每次启动都会重新求值的字段会被刷新。
--- 副作用：config 里的 autocmd 会再注册一遍（同 group 需要插件自己 clear）；
--- 键位只加不删：改过的 lhs 会用新 rhs 覆盖，但 spec 里删掉的键（全局的和 ft 的）
--- 都不会被回收，要重启才能消失。
---@param mod string 模块名，如 "plugins.dap.nvim-dap-view"
---@return boolean ok, string[]? names 重跑的插件名
function M.reload_spec(mod)
	package.loaded[mod] = nil
	local ok, ret = pcall(require, mod)
	if not ok then
		vim.notify(("reload %s 失败: %s"):format(mod, ret), vim.log.levels.ERROR)
		return false
	end
	if type(ret) ~= "table" then
		vim.notify(("reload %s: spec 文件应返回 table"):format(mod), vim.log.levels.WARN)
		return false
	end

	-- dependencies 只会影响加载顺序/config 里的 require，热重载做不到，只能判「变了没有」
	local function dep_names(spec)
		local set, n = {}, 0
		local list = spec and spec.dependencies
		if list == nil then
			return set, 0
		end
		if type(list) ~= "table" or (list[1] == nil and (list.dir or list.src or list.name)) then
			list = { list }
		end
		for _, dep in ipairs(list) do
			local d = normalize_spec(dep, 0)
			if d and not set[d.name] then
				set[d.name] = true
				n = n + 1
			end
		end
		return set, n
	end

	local function same_deps(a, b)
		local sa, na = dep_names(a)
		local sb, nb = dep_names(b)
		if na ~= nb then
			return false
		end
		for k in pairs(sa) do
			if not sb[k] then
				return false
			end
		end
		return true
	end

	local items = is_single_spec(ret) and { ret } or ret
	local names = {}
	for _, raw in ipairs(items) do
		local new_spec = normalize_spec(vim.deepcopy(raw), 0)
		if not new_spec then
			-- nil 条目（条件禁用之类）直接跳过
		else
			local spec = by_src[new_spec.src] or by_name[new_spec.name]
			if not spec then
				vim.notify(
					("reload %s: %s 本次启动未注册（新增插件请重启）"):format(mod, new_spec.name),
					vim.log.levels.WARN
				)
			else
				-- 结构性字段（源/依赖/启停/优先级/main）改了必须重启，照常热重载只会
				-- 把新旧状态混在一起（config 重跑，但 rtp 里的插件还是旧的）
				local changed = {}
				if new_spec.src ~= spec.src then
					changed[#changed + 1] = "src/dir"
				end
				if (new_spec._disabled or false) ~= (spec._disabled or false) then
					changed[#changed + 1] = "enabled"
				end
				if new_spec._priority ~= spec._priority then
					changed[#changed + 1] = "priority"
				end
				if (new_spec.main or "") ~= (spec.main or "") then
					changed[#changed + 1] = "main"
				end
				if not same_deps(new_spec, spec) then
					changed[#changed + 1] = "dependencies"
				end
				if #changed > 0 then
					vim.notify(
						("reload %s: %s 的 %s 改了，需重启 nvim 生效（本次跳过）"):format(
							mod,
							spec.name,
							table.concat(changed, "/")
						),
						vim.log.levels.WARN
					)
					goto continue
				end
				spec.config = new_spec.config
				spec.opts = new_spec.opts
				spec.init = new_spec.init
				spec.keys = new_spec.keys
				-- 让 apply_keys 重新登记：否则 key_owner 去重会让新键位永远装不上
				for id, rec in pairs(key_owner) do
					if rec.owner == spec.name then
						key_owner[id] = nil
					end
				end
				for i = #ft_pending, 1, -1 do
					if ft_pending[i].spec == spec.name then
						table.remove(ft_pending, i)
					end
				end
				run_init(spec)
				configure_spec(spec)
				names[#names + 1] = spec.name
				::continue::
			end
		end
	end

	-- fail() 只是把错误攒着等启动结束时统一报，重载时要立刻让用户看到
	backfill_ft_keys()
	report_errors()

	if #names == 0 then
		return false, names
	end
	return true, names
end

--- dev 插件（src 是本地目录）的名字，供清理 vim.pack 遗留副本用
---@return string[]
---锁文件内容（name -> { src, rev }）：pack_local 判断「删目录后会不会被重建」用
---@return table<string, {src: string?, rev: string?}>
function M.lock_plugins()
	return lock_plugins()
end

function M.dev_names()
	local names = {}
	for _, spec in ipairs(order) do
		if spec._dev then
			names[#names + 1] = spec.name
		end
	end
	return names
end

--- spec 目录（给外部做「当前文件属于哪个 spec」推断用）
---@return string
function M.spec_dir()
	return spec_dir
end

require("boot.pack_local").setup({ dev_names = M.dev_names, pack_root = pack_root })

return M
