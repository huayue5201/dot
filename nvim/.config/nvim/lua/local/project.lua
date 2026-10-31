-- 项目概览：一次看清「这仓库是什么、有多大、怎么组织、最近在动什么、怎么构建、有什么约定」。
--
--   :Project        精简版（身份 / 规模 / 结构 / 活跃区 / 构建入口）
--   :Project!       完整版（再加 依赖 / 约定 / 规模细节）
--   <leader>ii      打开精简版（i = info；<leader>p 是 yanky 的粘贴前缀，别抢）
-- 窗口内：q / <Esc> 关闭，t 精简⇄完整，r 重新采集，gd 跳到光标下的文件/目录。
-- 非 git 目录也能用：直接按目录统计（跳过 node_modules/target/dist 这类依赖与产物）。
--
-- 为什么自己写：这类需求分散在 tokei 插件（只管行数）、gitsigns（只管 diff）、
-- neogit（只管提交）里，价值恰恰在「一屏、一次、按阅读顺序排好版」。
--
-- 实现要点：
--   * 采集走 vim.system：重活（tokei / git log）并行异步，结果回主线程渲染；
--     按 toplevel + HEAD 缓存在内存里，t 切换档位不重新跑命令。
--   * 语言行数优先 tokei（扣注释/空行、语言识别准），没装自动回落 git ls-files + wc -l
--     （含注释与空行、按扩展名猜语言），报告里会标明数据来源。
--   * 「活跃区」= 最近 90 天 git log 改动次数排序。新项目真正该先读的通常不是 README
--     吹的架构，而是最近还在动的文件。
--   * buffer 是 buftype=nofile 的 markdown（只读，可 yank / 搜索 / gd 跳转），并主动
--     关掉 markview 的原地渲染：这里是数据表，不需要二次排版。

local M = {}

local cache = {} -- root -> { head = string, data = table }
local state = {} -- bufnr -> { root, data, full, paths, origin_win }
local last ---@type { root: string, data: table }|nil -- 最近一次采集（:ProjectAsk 复用，避免重复跑 tokei）

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Project" })
end

local function join(root, path)
	return vim.fs.joinpath(root, path)
end

local function split_lines(text)
	if not text or text == "" then
		return {}
	end
	return vim.split(text, "\n", { trimempty = true })
end

---@return string|nil 去掉行尾空白后的 stdout；非 0 退出码返回 nil
local function git_sync(cwd, args, timeout)
	local cmd = { "git" }
	vim.list_extend(cmd, args)
	local ok, obj = pcall(vim.system, cmd, { cwd = cwd, text = true, timeout = timeout or 15000 })
	if not ok then
		return nil
	end
	local res = obj:wait()
	if res.code ~= 0 then
		return nil
	end
	return (res.stdout or ""):gsub("%s+$", "")
end

--- 并行跑一组命令，任意一条失败只影响它自己的结果（nil）
local function run_parallel(cwd, jobs, done)
	local pending = #jobs
	local results = {}
	if pending == 0 then
		return done(results)
	end
	local function finish(i, stdout)
		results[i] = stdout
		pending = pending - 1
		if pending == 0 then
			vim.schedule(function()
				done(results)
			end)
		end
	end
	for i, job in ipairs(jobs) do
		local ok = pcall(vim.system, job.cmd, { cwd = cwd, text = true, timeout = job.timeout or 60000 }, function(obj)
			finish(i, obj.code == 0 and (obj.stdout or "") or nil)
		end)
		if not ok then
			finish(i, nil)
		end
	end
end

local function read_lines(path, max)
	local out = {}
	local ok, f = pcall(io.open, path, "r")
	if not ok or not f then
		return out
	end
	for line in f:lines() do
		out[#out + 1] = line
		if max and #out >= max then
			break
		end
	end
	f:close()
	return out
end

local function num(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

--- 小数比例，如 0.173 -> "17%"
local function pct(part, total)
	if not total or total == 0 then
		return "0%"
	end
	return ("%d%%"):format(math.floor(part / total * 100 + 0.5))
end

local EXT_LANG = {
	lua = "Lua",
	md = "Markdown",
	markdown = "Markdown",
	json = "JSON",
	jsonc = "JSON",
	toml = "TOML",
	yaml = "YAML",
	yml = "YAML",
	sh = "Shell",
	bash = "Shell",
	zsh = "Shell",
	py = "Python",
	rs = "Rust",
	go = "Go",
	c = "C",
	h = "C",
	cpp = "C++",
	cc = "C++",
	cxx = "C++",
	hpp = "C++",
	ts = "TypeScript",
	tsx = "TSX",
	js = "JavaScript",
	jsx = "JavaScript",
	css = "CSS",
	scss = "SCSS",
	html = "HTML",
	vim = "Vim script",
	nix = "Nix",
	sql = "SQL",
	tex = "TeX",
	zig = "Zig",
	java = "Java",
	kt = "Kotlin",
	rb = "Ruby",
	php = "PHP",
	swift = "Swift",
	cs = "C#",
	ex = "Elixir",
	exs = "Elixir",
	hs = "Haskell",
	ml = "OCaml",
	mli = "OCaml",
	scala = "Scala",
	dart = "Dart",
	vue = "Vue",
	svelte = "Svelte",
	txt = "Text",
}

local BINARY_EXT = {
	png = true,
	jpg = true,
	jpeg = true,
	gif = true,
	webp = true,
	bmp = true,
	ico = true,
	pdf = true,
	zip = true,
	gz = true,
	tgz = true,
	tar = true,
	xz = true,
	zst = true,
	woff = true,
	woff2 = true,
	ttf = true,
	otf = true,
	mp4 = true,
	mov = true,
	webm = true,
	mp3 = true,
	wav = true,
	so = true,
	dylib = true,
	wasm = true,
	jar = true,
	class = true,
	db = true,
	sqlite = true,
	sqlite3 = true,
}

-- 生成物/锁定文件：算进「规模」只会虚高，且永远不是你要读的代码
local NOISE_NAMES = {
	["lazy-lock.json"] = true,
	["package-lock.json"] = true,
	["pnpm-lock.yaml"] = true,
	["yarn.lock"] = true,
	["Cargo.lock"] = true,
	["poetry.lock"] = true,
	["uv.lock"] = true,
	["composer.lock"] = true,
	["Gemfile.lock"] = true,
	["flake.lock"] = true,
}

local NOISE_PATTERNS = {
	"%.lock$",
	"%-lock%.json$",
	"^go%.sum$",
	"%.min%.js$",
	"%.min%.css$",
	"%.svg$",
	"%.csv$",
	"%.ipynb$",
	"%.log$",
}

local function is_noise(path)
	if NOISE_NAMES[vim.fs.basename(path)] then
		return true
	end
	for _, pat in ipairs(NOISE_PATTERNS) do
		if path:find(pat) then
			return true
		end
	end
	return false
end

local function is_binary(path)
	local ext = path:match("%.([%w]+)$")
	return ext ~= nil and BINARY_EXT[ext:lower()] == true
end
--- 不是 git 仓库时的兜底：自己走目录。跳过依赖/构建产物（node_modules、target…），
--- 否则一个 node_modules 就能把统计灌满。
local WALK_SKIP = {
	[".git"] = true,
	["node_modules"] = true,
	[".venv"] = true,
	["venv"] = true,
	["target"] = true,
	["__pycache__"] = true,
	[".cache"] = true,
	["dist"] = true,
	["build"] = true,
}

local function walk_files(root, limit)
	local files, queue = {}, { "" }
	while #queue > 0 and #files < limit do
		local rel = table.remove(queue, 1)
		local handle = vim.uv.fs_scandir(join(root, rel))
		if handle then
			while #files < limit do
				local name, kind = vim.uv.fs_scandir_next(handle)
				if not name then
					break
				end
				local child = rel == "" and name or (rel .. "/" .. name)
				if kind == "directory" then
					if not WALK_SKIP[name] then
						queue[#queue + 1] = child
					end
				elseif kind == "file" and not is_binary(child) then
					files[#files + 1] = child
				end
			end
		end
	end
	table.sort(files)
	return files
end


local function lang_of(path)
	local ext = path:match("%.([%w]+)$")
	return ext and EXT_LANG[ext:lower()] or "其他"
end

----------------------------------------------------------------------
-- 各个数据源
----------------------------------------------------------------------

local LICENSE_FILES = { "LICENSE", "LICENSE.md", "LICENSE.txt", "COPYING", "COPYING.md", "LICENCE" }

local function detect_license(root, fileset)
	for _, name in ipairs(LICENSE_FILES) do
		if fileset[name] then
			local txt = table.concat(read_lines(join(root, name), 40), " "):lower()
			if txt:find("mit license", 1, true) then
				return "MIT"
			elseif txt:find("apache license", 1, true) then
				return "Apache-2.0"
			elseif txt:find("gnu general public", 1, true) then
				return "GPL"
			elseif txt:find("mozilla public", 1, true) then
				return "MPL-2.0"
			elseif txt:find("bsd", 1, true) then
				return "BSD"
			end
			return name
		end
	end
	return nil
end

--- README 里第一个标题，当作项目自称的名字
local function readme_title(root, fileset)
	for _, name in ipairs({ "README.md", "README.markdown", "README.rst", "README.txt", "README" }) do
		if fileset[name] then
			for _, line in ipairs(read_lines(join(root, name), 60)) do
				-- markdown/rst 标题：`# Foo` / `Foo\n===`
				local title = line:match("^#%s+(.+)$") or line:match("^([%u][^#%=]+)$")
				if title then
					title = vim.trim(title:gsub("[=%s]+$", ""))
					if #title > 2 and #title < 100 then
						return title
					end
				end
			end
			return nil
		end
	end
	return nil
end

--- tokei 的 JSON：{ Lua = { code, comments, blanks, reports = { { name, stats } } } }
local function parse_tokei(stdout)
	local ok, data = pcall(vim.json.decode, stdout or "")
	if not ok or type(data) ~= "table" then
		return nil
	end
	local langs, filelines = {}, {}
	local code, comments, blanks = 0, 0, 0
	for lang, info in pairs(data) do
		-- "Total" 是 tokei 自己汇总出来的伪语言
		if lang ~= "Total" and type(info) == "table" and type(info.code) == "number" then
			langs[#langs + 1] = { name = lang, code = info.code, files = type(info.reports) == "table" and #info.reports or 0 }
			code, comments, blanks = code + info.code, comments + (info.comments or 0), blanks + (info.blanks or 0)
			for _, rep in ipairs(info.reports or {}) do
				if type(rep) == "table" and type(rep.name) == "string" then
					-- tokei 的路径带 "./" 前缀，去掉才能和 git ls-files 的路径对上
					local path = rep.name:gsub("^%./", "")
					if not is_noise(path) then
						filelines[path] = (type(rep.stats) == "table" and rep.stats.code) or 0
					end
				end
			end
		end
	end
	if code == 0 and #langs == 0 then
		return nil
	end
	table.sort(langs, function(a, b)
		return a.code > b.code
	end)
	return {
		langs = langs,
		filelines = filelines,
		code = code,
		comments = comments,
		blanks = blanks,
		source = "tokei，不含注释/空行",
	}
end

--- wc 回落：stdout 每行「<数量> <路径>」（路径里可以有空格，数量在前）
local function parse_wc(stdout)
	local filelines, by_lang = {}, {}
	local code = 0
	for line in (stdout or ""):gmatch("[^\n]+") do
		local n, path = line:match("^%s*(%d+)%s+(.+)$")
		-- xargs 分批跑，每批会多打一行「total N」
		if n and path ~= "total" and not is_binary(path) and not is_noise(path) then
			n = tonumber(n)
			filelines[path] = n
			local lang = lang_of(path)
			local entry = by_lang[lang] or { name = lang, code = 0, files = 0 }
			entry.code, entry.files = entry.code + n, entry.files + 1
			by_lang[lang] = entry
			code = code + n
		end
	end
	local langs = {}
	for _, entry in pairs(by_lang) do
		langs[#langs + 1] = entry
	end
	table.sort(langs, function(a, b)
		return a.code > b.code
	end)
	return {
		langs = langs,
		filelines = filelines,
		code = code,
		comments = nil,
		blanks = nil,
		source = "wc -l（含注释与空行，按扩展名猜语言）",
		files = files,
	}
end

--- 目录结构：先建目录树，再反复把「当前最大的目录」换成一层的子目录，
--- 直到条目数够用。这样 lua/plugins/ 这种真正有内容的目录会自己浮出来，
--- 而不是被 nvim/.config/ 这类三层单链嵌套吃掉。
local MAX_STRUCT_ENTRIES = 12

local function aggregate_structure(files, filelines)
	local root = { path = "", lines = 0, files = 0, children = {}, index = {} }
	for _, path in ipairs(files) do
		if not is_noise(path) then
			local parts = vim.split(path, "/", { plain = true })
			local node = root
			node.lines, node.files = node.lines + (filelines[path] or 0), node.files + 1
			for i = 1, #parts - 1 do
				local key = parts[i]
				local child = node.index[key]
				if not child then
					child = { name = key, lines = 0, files = 0, direct = 0, children = {}, index = {} }
					node.index[key] = child
					node.children[#node.children + 1] = child
				end
				node = child
				node.lines, node.files = node.lines + (filelines[path] or 0), node.files + 1
			end
			-- 文件自己所在的那层目录
			node.direct = (node.direct or 0) + 1
		end
	end

	-- 压缩单链：只有 1 个子目录、自己又不直接放文件的目录没有信息量，合并进路径
	local function contract(node)
		for _, child in ipairs(node.children) do
			contract(child)
		end
		while #node.children == 1 and (node.direct or 0) == 0 do
			local only = node.children[1]
			node.name = node.name .. "/" .. only.name
			node.children, node.index = only.children, only.index
			node.direct = only.direct
		end
	end
	contract(root)

	local entries = {}
	for _, child in ipairs(root.children) do
		child.path = child.name
		entries[#entries + 1] = child
	end

	local function by_size(a, b)
		if a.lines ~= b.lines then
			return a.lines > b.lines
		end
		return a.files > b.files
	end

	table.sort(entries, by_size)
	while #entries > MAX_STRUCT_ENTRIES do
		table.remove(entries)
	end

	-- 只拆「大到自己占一屏」的目录：拆之前腾位置，把比它小得多的条目淘汰掉，
	-- 这样 nvim/.config 这种三层单链会一路拆到 lua/plugins，而不会被 12 条上限卡住
	local keep_lines = math.max(1, math.floor(root.lines * 0.02))
	for _ = 1, 200 do
		local best, best_i
		for i, e in ipairs(entries) do
			-- 小于总量 2% 的目录不值得再拆（拆开只会得到一堆更碎的条目）
			if #e.children > 0 and e.lines >= keep_lines and (not best or e.lines > best.lines) then
				best, best_i = e, i
			end
		end
		if not best then
			break
		end
		local overflow = #entries - 1 + #best.children - MAX_STRUCT_ENTRIES
		if overflow > 0 then
			-- 淘汰候选：比当前目录小、且不到总量 2% 的条目，从小到大淘汰
			local victims = {}
			for i, e in ipairs(entries) do
				if i ~= best_i and e.lines < keep_lines then
					victims[#victims + 1] = i
				end
			end
			if #victims < overflow then
				break
			end
			table.sort(victims, function(a, b)
				return entries[a].lines < entries[b].lines
			end)
			local drop = {}
			for i = 1, overflow do
				drop[victims[i]] = true
			end
			local kept = {}
			for i, e in ipairs(entries) do
				if not drop[i] then
					kept[#kept + 1] = e
				end
			end
			entries = kept
			-- 重新定位 best（下标变了）
			for i, e in ipairs(entries) do
				if e == best then
					best_i = i
				end
			end
		end
		if not best_i then
			break
		end
		local expanded = {}
		for _, child in ipairs(best.children) do
			child.path = best.path .. "/" .. child.name
			expanded[#expanded + 1] = child
		end
		table.remove(entries, best_i)
		vim.list_extend(entries, expanded)
		table.sort(entries, by_size)
	end

	table.sort(entries, by_size)
	return entries
end

--- 最近 90 天改动文件计数
local function parse_active(stdout)
	local counts = {}
	for line in (stdout or ""):gmatch("[^\n]+") do
		line = vim.trim(line)
		if line ~= "" and not is_noise(line) then
			counts[line] = (counts[line] or 0) + 1
		end
	end
	local list = {}
	for path, n in pairs(counts) do
		list[#list + 1] = { path = path, count = n }
	end
	table.sort(list, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.path < b.path
	end)
	return list
end

--- 目录里的目标名（Makefile / justfile 的 recipe）
local function parse_targets(root, name, limit)
	local out = {}
	for _, line in ipairs(read_lines(join(root, name), 400)) do
		local target = line:match("^([%w_%.%-/]+):[^=]")
		if target and not vim.startswith(target, ".") then
			out[#out + 1] = target
			if #out >= limit then
				break
			end
		end
	end
	return out
end

local function toml_section_keys(root, name, wanted_sections, limit)
	local keys, section = {}, nil
	for _, line in ipairs(read_lines(join(root, name), 800)) do
		local header = line:match("^%s*%[([%w_%.%-]+)%]%s*$")
		if header then
			section = header
		else
			local key = line:match('^%s*([%w_%-]+)%s*=')
			if key and section and wanted_sections[section] then
				keys[#keys + 1] = key
				if #keys >= limit then
					break
				end
			end
		end
	end
	return keys
end

----------------------------------------------------------------------
-- 采集
----------------------------------------------------------------------

local function detect_build(root, fileset, full)
	local out = {}
	local function note(text)
		out[#out + 1] = text
	end

	if fileset["flake.nix"] then
		note("flake.nix（nix develop / nix run）")
	end
	if fileset["Makefile"] or fileset["makefile"] then
		local name = fileset["Makefile"] and "Makefile" or "makefile"
		local targets = parse_targets(root, name, 8)
		note(name .. (#targets > 0 and ("：make " .. table.concat(targets, " / ")) or ""))
	end
	if fileset["justfile"] or fileset["Justfile"] then
		local name = fileset["justfile"] and "justfile" or "Justfile"
		local targets = parse_targets(root, name, 8)
		note(name .. (#targets > 0 and ("：just " .. table.concat(targets, " / ")) or ""))
	end
	if fileset["package.json"] then
		local ok, pkg = pcall(vim.json.decode, table.concat(read_lines(join(root, "package.json")), "\n"))
		if ok and type(pkg) == "table" then
			local bits = {}
			if type(pkg.scripts) == "table" then
				local names = vim.tbl_keys(pkg.scripts)
				table.sort(names)
				bits[#bits + 1] = "npm run " .. table.concat(vim.list_slice(names, 1, 6), " / ")
			end
			if type(pkg.bin) == "string" then
				bits[#bits + 1] = "bin: " .. pkg.bin
			elseif type(pkg.bin) == "table" then
				bits[#bits + 1] = "bin: " .. table.concat(vim.tbl_keys(pkg.bin), ", ")
			elseif type(pkg.main) == "string" then
				bits[#bits + 1] = "main: " .. pkg.main
			end
			note("package.json" .. (#bits > 0 and ("：" .. table.concat(bits, " · ")) or ""))
		else
			note("package.json")
		end
	end
	if fileset["Cargo.toml"] then
		local bins, name, version = {}, nil, nil
		for _, line in ipairs(read_lines(join(root, "Cargo.toml"), 400)) do
			local bin = line:match('^%s*name%s*=%s*"(.-)"')
			if bin and #bins > 0 then
				bins[#bins + 1] = bin
			end
			if not name then
				name = line:match('^name%s*=%s*"(.-)"')
				version = line:match('^version%s*=%s*"(.-)"')
			end
		end
		local bits = {}
		if name then
			bits[#bits + 1] = ("crate %s%s"):format(name, version and (" " .. version) or "")
		end
		if #bins > 0 then
			bits[#bits + 1] = "bin: " .. table.concat(bins, ", ")
		end
		if fileset["src/main.rs"] then
			bits[#bits + 1] = "入口 src/main.rs"
		elseif fileset["src/lib.rs"] then
			bits[#bits + 1] = "库 src/lib.rs"
		end
		note("Cargo.toml" .. (#bits > 0 and ("：" .. table.concat(bits, " · ")) or ""))
	end
	if fileset["go.mod"] then
		local module, goversion = nil, nil
		for _, line in ipairs(read_lines(join(root, "go.mod"), 60)) do
			module = module or line:match("^module%s+(%S+)")
			goversion = goversion or line:match("^go%s+(%S+)")
		end
		local bits = {}
		if module then
			bits[#bits + 1] = module
		end
		if goversion then
			bits[#bits + 1] = "go " .. goversion
		end
		note("go.mod" .. (#bits > 0 and ("：" .. table.concat(bits, " · ")) or ""))
	end
	if fileset["pyproject.toml"] then
		local name, version
		for _, line in ipairs(read_lines(join(root, "pyproject.toml"), 200)) do
			name = name or line:match('^name%s*=%s*"(.-)"')
			version = version or line:match('^version%s*=%s*"(.-)"')
		end
		note("pyproject.toml" .. ((name or version) and ("：" .. table.concat(vim.tbl_filter(function(x)
			return x ~= nil
		end, { name, version }), " ")) or ""))
	end
	if fileset["setup.py"] then
		note("setup.py")
	end
	if fileset["Dockerfile"] or fileset["docker-compose.yml"] or fileset["compose.yml"] then
		note("Docker： " .. table.concat(vim.tbl_filter(function(x)
			return fileset[x] and x or nil
		end, { "Dockerfile", "docker-compose.yml", "compose.yml" }), " · "))
	end
	return out
end

local function detect_deps(root, fileset)
	local deps = {}
	local function add(label, list)
		if #list > 0 then
			deps[#deps + 1] = { label = label, list = list }
		end
	end

	if fileset["package.json"] then
		local ok, pkg = pcall(vim.json.decode, table.concat(read_lines(join(root, "package.json")), "\n"))
		if ok and type(pkg) == "table" then
			for _, section in ipairs({ "dependencies", "devDependencies" }) do
				if type(pkg[section]) == "table" then
					local names = vim.tbl_keys(pkg[section])
					table.sort(names)
					add("npm " .. section, names)
				end
			end
		end
	end
	if fileset["Cargo.toml"] then
		add("cargo dependencies", toml_section_keys(root, "Cargo.toml", { dependencies = true, ["dev-dependencies"] = true }, 40))
	end
	if fileset["go.mod"] then
		local list = {}
		for _, line in ipairs(read_lines(join(root, "go.mod"), 200)) do
			local mod = line:match("^%s*([%w%.%-]+%.[%w%.%-/]+)%s+v[%d]")
			if mod then
				list[#list + 1] = mod
			end
		end
		add("go require", list)
	end
	if fileset["requirements.txt"] then
		local list = {}
		for _, line in ipairs(read_lines(join(root, "requirements.txt"), 100)) do
			local name = line:match("^([%w%._%-]+)")
			if name and not vim.startswith(line, "#") then
				list[#list + 1] = name
			end
		end
		add("requirements.txt", list)
	end
	return deps
end

local CONVENTION_FILES = {
	{ ".editorconfig", "缩进/换行约定" },
	{ ".gitattributes", "git 属性" },
	{ "stylua.toml", "Lua 格式化" },
	{ ".stylua.toml", "Lua 格式化" },
	{ ".luacheckrc", "Lua lint" },
	{ "rustfmt.toml", "Rust 格式化" },
	{ ".rustfmt.toml", "Rust 格式化" },
	{ ".golangci.yml", "Go lint" },
	{ ".golangci.yaml", "Go lint" },
	{ ".prettierrc", "JS/TS 格式化" },
	{ ".prettierrc.json", "JS/TS 格式化" },
	{ "eslint.config.js", "JS/TS lint" },
	{ ".eslintrc", "JS/TS lint" },
	{ "AGENTS.md", "给 agent 的约定" },
	{ "CLAUDE.md", "给 agent 的约定" },
	{ "CONTRIBUTING.md", "贡献流程" },
	{ "CODE_OF_CONDUCT.md", "行为准则" },
}

local function detect_conventions(root, fileset)
	local out = {}
	for _, item in ipairs(CONVENTION_FILES) do
		if fileset[item[1]] then
			out[#out + 1] = ("%s（%s）"):format(item[1], item[2])
		end
	end
	local ci = {}
	for _, name in ipairs({ ".github/workflows", ".gitlab-ci.yml", ".gitea/workflows", ".circleci/config.yml" }) do
		local matched = false
		for path in pairs(fileset) do
			if path == name or vim.startswith(path, name .. "/") then
				matched = true
				break
			end
		end
		if matched then
			ci[#ci + 1] = name
		end
	end
	if #ci > 0 then
		out[#out + 1] = "CI： " .. table.concat(ci, " · ")
	end
	local docs = {}
	for _, name in ipairs({ "README.md", "README.rst", "docs/", "doc/", "CONTRIBUTING.md", "AGENTS.md", "CHANGELOG.md" }) do
		if fileset[name] then
			docs[#docs + 1] = name
		end
	end
	if #docs > 0 then
		out[#out + 1] = "文档： " .. table.concat(docs, " · ")
	end
	return out
end

local TEST_PATTERNS = {
	"/tests?/",
	"/test_",
	"_test%.",
	"_spec%.",
	"%.spec%.",
	"%.test%.",
	"/spec/",
	"/__tests__/",
}

local function is_test_file(path)
	for _, pat in ipairs(TEST_PATTERNS) do
		if path:find(pat) then
			return true
		end
	end
	return false
end

local function build_data(info, results, full)
	local stats
	if results.tokei then
		stats = parse_tokei(results.tokei)
	end
	if not stats and results.wc then
		stats = parse_wc(results.wc)
	end
	stats = stats or { langs = {}, filelines = {}, code = 0, source = "无法统计", files = info.files }

	local files = info.files
	local filelines = stats.filelines or {}

	-- 最大文件（只列有行数的）
	local big = {}
	for path, lines in pairs(filelines) do
		if lines > 0 and not is_noise(path) then
			big[#big + 1] = { path = path, lines = lines }
		end
	end
	table.sort(big, function(a, b)
		if a.lines ~= b.lines then
			return a.lines > b.lines
		end
		return a.path < b.path
	end)

	local tests = 0
	for _, path in ipairs(files) do
		if is_test_file(path) then
			tests = tests + 1
		end
	end

	local todo = 0
	for line in (results.todo or ""):gmatch("[^\n]+") do
		todo = todo + (tonumber(line:match(":(%d+)$")) or 0)
	end

	return {
		root = info.root,
		name = info.name,
		git = info.git,
		branch = info.branch,
		head = info.head,
		date = info.date,
		tags = info.tags,
		dirty = info.dirty,
		license = info.license,
		readme_title = info.readme_title,
		files = files,
		code = stats.code,
		source = stats.source,
		langs = stats.langs or {},
		big = big,
		structure = aggregate_structure(files, filelines),
		active = parse_active(results.log),
		tests = tests,
		build = detect_build(info.root, info.fileset, full),
		deps = detect_deps(info.root, info.fileset),
		conventions = detect_conventions(info.root, info.fileset),
		todo = todo,
	}
end

local function collect(root, full, done)
	local is_git = git_sync(root, { "rev-parse", "--is-inside-work-tree" }) == "true"
	local files
	if is_git then
		files = split_lines(git_sync(root, { "ls-files" }))
	else
		files = walk_files(root, 20000)
	end
	local fileset = {}
	for _, path in ipairs(files) do
		fileset[path] = true
	end

	local info = {
		root = root,
		name = vim.fs.basename(root),
		git = is_git,
		branch = is_git and git_sync(root, { "rev-parse", "--abbrev-ref", "HEAD" }) or nil,
		head = is_git and git_sync(root, { "rev-parse", "--short", "HEAD" }) or nil,
		date = is_git and git_sync(root, { "log", "-1", "--format=%cs" }) or nil,
		tags = is_git and split_lines(git_sync(root, { "tag", "--sort=-v:refname" })) or {},
		dirty = is_git and #split_lines(git_sync(root, { "status", "--porcelain" })) or 0,
		license = detect_license(root, fileset),
		readme_title = readme_title(root, fileset),
		files = files,
		fileset = fileset,
	}

	local jobs = {}
	if vim.fn.executable("tokei") == 1 then
		-- --hidden：git 仓库里 `.config/` 这类目录默认被 tokei 跳过（dotfiles 仓库全靠它）。
		-- -e：依赖/产物目录永远不是你要读的代码（tokei 只认 .gitignore，非 git 目录会全灌进来）
		jobs[#jobs + 1] = {
			key = "tokei",
			cmd = {
				"tokei",
				"--output",
				"json",
				"--hidden",
				"-e",
				"node_modules",
				"-e",
				".venv",
				"-e",
				"__pycache__",
				"-e",
				"target",
				"-e",
				"dist",
				"-e",
				"build",
			},
			timeout = 120000,
		}
	else
		jobs[#jobs + 1] = {
			key = "wc",
			cmd = {
				"sh",
				"-c",
				is_git and "git ls-files -z | xargs -0 -n 200 wc -l 2>/dev/null"
					or "find . -type f ! -path './.git/*' ! -path '*/node_modules/*' ! -path '*/target/*' -print0 | xargs -0 -n 200 wc -l 2>/dev/null",
			},
			timeout = 120000,
		}
	end
	if is_git then
		jobs[#jobs + 1] = {
			key = "log",
			cmd = { "git", "log", "--since=90 days ago", "--name-only", "--pretty=format:" },
		}
		if full then
			jobs[#jobs + 1] = { key = "todo", cmd = { "git", "grep", "-I", "-c", "-E", "TODO|FIXME" } }
		end
	end

	run_parallel(root, jobs, function(results)
		local named = {}
		for i, job in ipairs(jobs) do
			named[job.key] = results[i]
		end
		done(build_data(info, named, full))
	end)
end

----------------------------------------------------------------------
-- 渲染
----------------------------------------------------------------------

local function render(data, full)
	local L, paths = {}, {}
	local function add(text, path)
		L[#L + 1] = text
		if path then
			paths[#L] = path
		end
	end

	add(("# %s"):format(data.name))
	add("")
	if data.git then
		add(("%s  ·  %s @ %s（%s）"):format(data.root, data.branch, data.head, data.date))
	else
		add(("%s  ·  不是 git 仓库（按目录直接统计）"):format(data.root))
	end

	local meta = {}
	if data.license then
		meta[#meta + 1] = data.license
	end
	if #data.tags > 0 then
		meta[#meta + 1] = ("%d 个 tag（最新 %s）"):format(#data.tags, data.tags[1])
	end
	if data.git then
		meta[#meta + 1] = data.dirty > 0 and ("%d 个未提交改动"):format(data.dirty) or "工作区干净"
	end
	add(table.concat(meta, "  ·  "))
	if data.readme_title and data.readme_title ~= data.name then
		add(("README： %s"):format(data.readme_title))
	end

	-- 规模
	add("")
	add("## 规模")
	add(("%s 行（%s）  ·  %d 个文件"):format(num(data.code), data.source, #data.files))
	if #data.langs > 0 then
		local parts = {}
		for _, lang in ipairs(vim.list_slice(data.langs, 1, 6)) do
			parts[#parts + 1] = ("%s %s"):format(lang.name, num(lang.code))
		end
		add("- 语言： " .. table.concat(parts, " · "))
	end
	if #data.big > 0 then
		add("- 最大文件：")
		for _, f in ipairs(vim.list_slice(data.big, 1, 5)) do
			add(("  - %s — %sL"):format(f.path, num(f.lines)), f.path)
		end
	end
	if full then
		add(("- 测试文件： %d 个（占 %s）"):format(data.tests, pct(data.tests, #data.files)))
	end

	-- 结构
	if #data.structure > 0 then
		add("")
		add("## 结构（按行数）")
		local shown = 0
		for _, d in ipairs(data.structure) do
			if shown >= 12 then
				break
			end
			shown = shown + 1
			add(("- `%s`  %d 个文件  %sL"):format(d.path or d.name, d.files, num(d.lines)), d.path or d.name)
		end
		if #data.structure > shown then
			add(("- …另有 %d 个目录没展开"):format(#data.structure - shown))
		end
	end

	-- 活跃区（只看 git 历史，非 git 仓库没有这块）
	if not data.git then
		-- 跳过
	elseif #data.active > 0 then
		add("")
		add("## 活跃区（最近 90 天改动次数）")
		for _, f in ipairs(vim.list_slice(data.active, 1, full and 15 or 8)) do
			add(("- %d×  %s"):format(f.count, f.path), f.path)
		end
	else
		add("")
		add("## 活跃区")
		add("- 最近 90 天没有改动（或只有 merge / 空历史）")
	end

	-- 构建
	add("")
	add("## 构建 / 入口")
	if #data.build == 0 then
		add("- 没找到 Makefile / justfile / flake / manifest，可能是纯脚本或文档仓")
	else
		for _, line in ipairs(data.build) do
			add("- " .. line)
		end
	end

	if full then
		add("")
		add("## 依赖")
		if #data.deps == 0 then
			add("- 没解析到依赖（没有 package.json / Cargo.toml / go.mod / requirements.txt）")
		else
			for _, dep in ipairs(data.deps) do
				local list = dep.list
				local shown = table.concat(vim.list_slice(list, 1, 12), ", ")
				if #list > 12 then
					shown = shown .. (" … 共 %d 项"):format(#list)
				end
				add(("- %s： %s"):format(dep.label, shown))
			end
		end

		add("")
		add("## 约定 / 工程设施")
		if #data.conventions == 0 then
			add("- 没有任何约定文件（.editorconfig / lint / CI / AGENTS.md）")
		else
			for _, line in ipairs(data.conventions) do
				add("- " .. line)
			end
		end
		if data.todo > 0 then
			add(("- TODO / FIXME： %d 处"):format(data.todo))
		end
	end

	add("")
	add(
		("- `t` %s · `A` 发去问 AI · `C` 放进 chat · `q` 关闭 · `gd` 跳到光标下的文件/目录 · `r` 重新采集"):format(
			full and "只看精简" or "看完整版"
		)
	)

	return L, paths
end

----------------------------------------------------------------------
-- 给 AI 的紧凑摘要（digest）
----------------------------------------------------------------------

-- 阅读契约：摘要里带一句，省得每次提问都重复交代，也防止 agent 先去全库乱搜
local ASK_CONTRACT =
	"answer_from_digest: 只依据本摘要回答结构/规模/归属类问题；摘要覆盖不到的，先列出要读的文件和行范围，不要用 find/grep 全库探查"

--- 粗略 token 估算：ASCII 约 4 字符/token，中文约 1 字符/token
---@param text string
---@return integer
local function est_tokens(text)
	local bytes = #text
	local chars = vim.fn.strchars(text)
	local cjk = math.max(0, (bytes - chars) / 2)
	return math.ceil(cjk + (chars - cjk) / 4)
end

--- 把 data 压成 300~400 token 的「索引式」摘要：每行一类事实，路径原样，不带易变时间戳
---@param data table
---@return string
local function digest(data)
	local L = {}
	local head = { "PROJECT", data.name }
	if data.git then
		head[#head + 1] = "@ " .. (data.head or "?")
		if data.dirty > 0 then
			head[#head + 1] = ("dirty=%d"):format(data.dirty)
		end
	end
	L[#L + 1] = table.concat(head, " ")

	local root = { "root", data.root, data.git and "git" or "no-git" }
	if data.git then
		root[#root + 1] = "branch=" .. (data.branch or "?")
		root[#root + 1] = "last_commit=" .. (data.date or "?")
		if #data.tags > 0 then
			root[#root + 1] = ("tags=%d"):format(#data.tags)
		end
	end
	if data.license then
		root[#root + 1] = "license=" .. data.license
	end
	L[#L + 1] = table.concat(root, " ")

	-- source 用英文短标签：中文进摘要只会多花 token
	local stats_tag = data.source:find("tokei", 1, true) and "tokei(code only)" or "wc(all lines)"
	L[#L + 1] = ("scale code_lines=%d files=%d stats=%s"):format(data.code, #data.files, stats_tag)

	if #data.langs > 0 then
		local parts = {}
		for _, lang in ipairs(vim.list_slice(data.langs, 1, 5)) do
			if lang.code > 0 then
				parts[#parts + 1] = ("%s:%d"):format(lang.name, lang.code)
			end
		end
		L[#L + 1] = "langs " .. table.concat(parts, " ")
	end

	if #data.structure > 0 then
		local parts = {}
		for _, d in ipairs(vim.list_slice(data.structure, 1, 8)) do
			parts[#parts + 1] = ("%s %df/%dL"):format(d.path or d.name, d.files, d.lines)
		end
		L[#L + 1] = "dirs " .. table.concat(parts, " | ")
	end

	if #data.big > 0 then
		local parts = {}
		for _, f in ipairs(vim.list_slice(data.big, 1, 5)) do
			parts[#parts + 1] = ("%s %dL"):format(f.path, f.lines)
		end
		L[#L + 1] = "biggest " .. table.concat(parts, " | ")
	end

	if data.git and #data.active > 0 then
		local parts = {}
		for _, f in ipairs(vim.list_slice(data.active, 1, 5)) do
			parts[#parts + 1] = ("%s %dx"):format(f.path, f.count)
		end
		L[#L + 1] = "hot_90d_commits " .. table.concat(parts, " | ")
	end

	if #data.build > 0 then
		L[#L + 1] = "build " .. table.concat(vim.list_slice(data.build, 1, 3), " ; ")
	end
	if #data.deps > 0 then
		local parts = {}
		for _, dep in ipairs(vim.list_slice(data.deps, 1, 2)) do
			parts[#parts + 1] = ("%s=%s"):format(dep.label, table.concat(vim.list_slice(dep.list, 1, 6), ","))
		end
		L[#L + 1] = "deps " .. table.concat(parts, " ; ")
	end

	local misc = { ("tests=%d/%d"):format(data.tests, #data.files) }
	if data.todo > 0 then
		misc[#misc + 1] = ("todo_fixme=%d"):format(data.todo)
	end
	if #data.conventions > 0 then
		misc[#misc + 1] = "conventions=" .. #data.conventions
	end
	L[#L + 1] = table.concat(misc, " ")

	L[#L + 1] = "NOT_INCLUDED 代码正文（本摘要只有结构与统计，没有任何源码）"
	L[#L + 1] = ASK_CONTRACT
	return table.concat(L, "\n")
end

--- 把一份概览 data 渲染成给 AI 的摘要（公开：其它模块/MCP 可直接调用）
---@param data table
---@return string text
---@return integer tokens 粗略估算
function M.digest(data)
	local text = digest(data)
	return text, est_tokens(text)
end


--- 当前 buffer 对应的根目录（不在 git 里就退回 cwd）
---@param root_opt string|nil
---@return string
local function resolve_root(root_opt)
	local root = root_opt
		or git_sync(vim.fn.getcwd(), { "rev-parse", "--show-toplevel" })
		or vim.fn.getcwd()
	return vim.fs.normalize(root)
end

--- 打开提问浮窗，摘要作为 <project-overview> 随问题一起发出（走 local.ai 的后端通道）
---@param data table
---@param opts? { prompt?: string }
local function ask_ai(data, opts)
	opts = opts or {}
	local ok, ai = pcall(require, "local.ai")
	if not ok then
		notify("没有 local.ai 模块，无法发问")
		return
	end
	local text, tokens = M.digest(data)
	local ok_ask, err = pcall(ai.ask, {
		note = ("概览 ~%d tok"):format(tokens),
		extension = { digest = text },
	})
	if not ok_ask then
		notify(tostring(err), vim.log.levels.WARN)
	end
end

--- 拿到「当前项目」的概览数据：概览 buffer 现成的 → 最近采集 → 否则就地采一次
---@param opts { root?: string }
---@param cb fun(data: table)
local function with_data(opts, cb)
	local st = state[vim.api.nvim_get_current_buf()]
	if st and st.data then
		return cb(st.data)
	end
	local root = resolve_root(opts.root)
	-- 刚看过概览（在任何 buffer 里）：直接用那份数据，省掉一次采集
	if last and last.root == root then
		return cb(last.data)
	end
	collect(root, opts.full == true, cb)
end

--- 就当前项目问 AI：在概览 buffer 里直接用现成数据，否则就地采集一次
---@param opts? { root?: string }
function M.ask(opts)
	opts = opts or {}
	with_data(opts, function(data)
		ask_ai(data, opts)
	end)
end

--- 把概览摘要塞进 codecompanion 的 chat（不自动提交，你在里面接着问）
---@param opts? { root?: string, adapter?: string }
function M.chat(opts)
	opts = opts or {}
	with_data(opts, function(data)
		local ok, cc = pcall(require, "codecompanion")
		if not ok then
			notify("没有 codecompanion 插件，改用 :ProjectAsk", vim.log.levels.WARN)
			return
		end
		local text, tokens = M.digest(data)
		local adapter = opts.adapter or "deepseek"
		local chat_opts = {
			-- auto_submit=false：只把摘要放进去，问题由你在 chat 里写（避免替你猜问题）
			auto_submit = false,
			messages = {
				{
					role = "user",
					content = ("（项目概览索引，供后续提问参考；只有结构与统计，不含源码）\n\n<project-overview>\n%s\n</project-overview>"):format(
						text
					),
				},
			},
		}
		if adapter ~= "default" then
			chat_opts.params = { adapter = adapter }
		end
		local sent, err = pcall(cc.chat, chat_opts)
		if not sent then
			notify("打开 codecompanion chat 失败：" .. tostring(err), vim.log.levels.WARN)
			return
		end
		notify(("概览已放进 chat（adapter=%s，~%d tok）：接着在里面提问即可"):format(adapter, tokens), vim.log.levels.INFO)
	end)
end

--- RPC 入口（给 pi 的 nvim 工具用）：按 root 返回紧凑摘要，不依赖当前 buffer
--- 优先顺序：最近采集 → 本根目录缓存（HEAD 相同）→ 现采一次（用 vim.wait 等到结果）
---@param req { root?: string, path?: string, full?: boolean, wait_ms?: number }
---@return table
function M.bridge(req)
	req = req or {}
	local root = resolve_root(req.root or req.path)
	local origin = "last"
	local data
	if last and last.root == root then
		data = last.data
	end
	if not data then
		local snapshot = cache[root]
		if snapshot and snapshot.head == git_sync(root, { "rev-parse", "--short", "HEAD" }) then
			data = snapshot.data
			origin = "cache"
		end
	end
	if not data then
		local got
		collect(root, req.full == true, function(d)
			got = d
		end)
		local wait_ms = tonumber(req.wait_ms) or 45000
		vim.wait(wait_ms, function()
			return got ~= nil
		end, 50)
		if not got then
			return {
				ok = false,
				error = ("采集 %s 超时（%dms）：大仓库首次跑 tokei 可能较慢，稍后重试"):format(root, wait_ms),
			}
		end
		data = got
		origin = "fresh"
		last = { root = root, data = data }
	end
	local text, tokens = M.digest(data)
	return {
		ok = true,
		action = "project",
		root = root,
		origin = origin,
		git = data.git,
		tokens = tokens,
		digest = text,
	}
end

----------------------------------------------------------------------
-- 窗口 / 按键
----------------------------------------------------------------------

local function jump(buf)
	local st = state[buf]
	if not st then
		return
	end
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local path = st.paths[line]
	if not path then
		notify("光标这一行没有文件路径（试试「结构」「活跃区」「最大文件」里的条目）", vim.log.levels.WARN)
		return
	end
	local target = join(st.root, path)
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_close(win, true)
	if st.origin_win and vim.api.nvim_win_is_valid(st.origin_win) then
		vim.api.nvim_set_current_win(st.origin_win)
	end
	vim.cmd.edit(vim.fn.fnameescape(target))
end

local function attach(buf, origin_win, origin_buf)
	state[buf] = { paths = {}, origin_win = origin_win }
	-- buffer 被 wipe 时清掉状态，别让 state 表越攒越大
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			state[buf] = nil
		end,
	})
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].undolevels = -1
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "markdown"

	local opts = { buffer = buf, silent = true, nowait = true }
	local function close()
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_close(win, true)
		-- 关掉概览回到原来的 buffer 时，别留下一个空的 nofile buffer
		if origin_buf and vim.api.nvim_buf_is_valid(origin_buf) then
			vim.api.nvim_set_current_buf(origin_buf)
		end
		if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
	vim.keymap.set("n", "q", close, vim.tbl_extend("force", opts, { desc = "关闭项目概览" }))
	vim.keymap.set("n", "<Esc>", close, vim.tbl_extend("force", opts, { desc = "关闭项目概览" }))
	vim.keymap.set("n", "gd", function()
		jump(buf)
	end, vim.tbl_extend("force", opts, { desc = "跳到光标下的文件" }))
	vim.keymap.set("n", "r", function()
		M.open({ full = state[buf].full, force = true })
	end, vim.tbl_extend("force", opts, { desc = "重新采集" }))
	-- 用 t 而不是 <Tab>：<Tab> 在 normal 模式等同于 <C-i>，会抢掉 jumplist 前进
	vim.keymap.set("n", "t", function()
		M.open({ full = not state[buf].full })
	end, vim.tbl_extend("force", opts, { desc = "精简 ⇄ 完整" }))
	-- A(Ask)：把这份概览的紧凑摘要连同一个问题发给 AI 后端（走 local.ai）
	vim.keymap.set("n", "A", function()
		local st = state[buf]
		if st and st.data then
			ask_ai(st.data)
		end
	end, vim.tbl_extend("force", opts, { desc = "带着概览问 AI" }))
	-- C(Chat)：把摘要塞进 codecompanion chat，在 chat 里接着聊
	vim.keymap.set("n", "C", function()
		local st = state[buf]
		if st and st.data then
			M.chat({})
		end
	end, vim.tbl_extend("force", opts, { desc = "概览进 codecompanion chat" }))
end

local function fill(buf, data, full)
	local lines, paths = render(data, full)
	state[buf].paths = paths
	state[buf].root = data.root
	state[buf].data = data
	state[buf].full = full
	-- 记一份「最近一次采集」，这样：ProjectAsk 在任何 buffer 里都能直接用，不用再跑一遍 tokei
	last = { root = data.root, data = data }
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
	end
end

--- 采集并渲染到已有 buffer（先占位再异步填）
local function start_collect(buf, root, full)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		("# %s"):format(vim.fs.basename(root)),
		"",
		"采集中（tokei / git log 并行跑，大仓库要几秒）…",
	})
	vim.bo[buf].modifiable = false
	collect(root, full, function(data)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		cache[data.root] = { head = data.head, data = data }
		fill(buf, data, full)
	end)
end

--- 打开/切换概览窗口
---@param opts? { full?: boolean, root?: string, force?: boolean }
function M.open(opts)
	opts = opts or {}
	-- 不在 git 仓库里也能用：就地按目录统计（collect 里会走 walk_files 兜底）
	local root = resolve_root(opts.root)
	local full = opts.full == true

	local function focus(buf)
		local wins = vim.fn.win_findbuf(buf)
		if #wins > 0 then
			vim.api.nvim_set_current_win(wins[1])
		end
	end

	-- 已经采集过这个仓库：复用那个 buffer（窗口被关掉的话重新 split 出来，缓存还在）
	for buf, st in pairs(state) do
		if vim.api.nvim_buf_is_valid(buf) and st.root == root then
			if #vim.fn.win_findbuf(buf) == 0 then
				vim.cmd("silent! botright split")
				vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
				vim.api.nvim_win_set_height(0, math.max(12, math.floor(vim.o.lines * 0.6)))
			end
			if opts.force then
				start_collect(buf, root, full)
			elseif st.data and st.full ~= full then
				fill(buf, st.data, full)
			end
			focus(buf)
			return
		end
	end

	local origin_win = vim.api.nvim_get_current_win()
	local origin_buf = vim.api.nvim_get_current_buf()
	local buf = vim.api.nvim_create_buf(false, true)
	-- 带 scheme 的名字：不会被当成 cwd 下的相对文件路径（也不和真实文件抢 buffer 名）。
	-- 先用仓库名（statusline 里短），重名再退回完整路径。
	local name = "project://" .. vim.fs.basename(root)
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == name then
			name = "project://" .. root
			break
		end
	end
	vim.api.nvim_buf_set_name(buf, name)
	-- 关掉 markview 的原地渲染：这里是数据表，二次排版只会加噪音（顺序：先禁后设 ft）
	pcall(function()
		require("markview.state").set_buffer_state(buf, { enable = false })
	end)

	attach(buf, origin_win, origin_buf)

	local win = vim.api.nvim_get_current_win()
	vim.cmd("silent! botright split")
	local newwin = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(newwin, buf)
	vim.api.nvim_win_set_height(newwin, math.max(12, math.floor(vim.o.lines * 0.6)))
	vim.api.nvim_set_current_win(newwin)
	state[buf].origin_win = win

	local cached = cache[root]
	if cached and cached.head == git_sync(root, { "rev-parse", "--short", "HEAD" }) then
		fill(buf, cached.data, full)
		return
	end

	start_collect(buf, root, full)
end

function M.setup()
	vim.api.nvim_create_user_command("Project", function(args)
		M.open({ full = args.bang })
	end, { bang = true, desc = "项目概览（!: 完整版）" })
	vim.api.nvim_create_user_command("ProjectAsk", function()
		M.ask()
	end, { desc = "带着项目概览问 AI（精简摘要随问题发出）" })
	vim.api.nvim_create_user_command("ProjectChat", function(args)
		M.chat({ adapter = args.args ~= "" and args.args or nil })
	end, {
		nargs = "?",
		desc = "把项目概览摘要放进 codecompanion chat（默认 deepseek，可传 pi）",
		complete = function()
			return { "deepseek", "pi", "default" }
		end,
	})
	vim.keymap.set("n", "<leader>ii", function()
		M.open()
	end, { desc = "项目概览（规模 / 结构 / 活跃区）" })
	vim.keymap.set("n", "<leader>ia", function()
		M.ask()
	end, { desc = "带着项目概览问 AI" })
	vim.keymap.set("n", "<leader>ic", function()
		M.chat()
	end, { desc = "项目概览放进 codecompanion chat" })
end

return M
