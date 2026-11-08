-- 项目概览：采集（文件清单 + 并行跑 tokei / git log，组装成一份 data）
local util = require("local.project.util")
local scan = require("local.project.scan")

local git_sync = util.git_sync
local split_lines = util.split_lines
local run_parallel = util.run_parallel
local walk_files = util.walk_files
local read_lines = util.read_lines
local join = util.join
local is_noise = util.is_noise

local detect_license = scan.detect_license
local readme_title = scan.readme_title
local parse_tokei = scan.parse_tokei
local parse_wc = scan.parse_wc
local aggregate_structure = scan.aggregate_structure
local parse_active = scan.parse_active
local parse_targets = scan.parse_targets
local toml_section_keys = scan.toml_section_keys

----------------------------------------------------------------------
-- 采集
----------------------------------------------------------------------

local function detect_build(root, fileset, full)
	local out = {}
	local function note(text)
		out[#out + 1] = text
	end

	if fileset["flake.nix"] then
		note("flake.nix (nix develop / nix run)")
	end
	if fileset["Makefile"] or fileset["makefile"] then
		local name = fileset["Makefile"] and "Makefile" or "makefile"
		local targets = parse_targets(root, name, 8)
		note(name .. (#targets > 0 and (": make " .. table.concat(targets, " / ")) or ""))
	end
	if fileset["justfile"] or fileset["Justfile"] then
		local name = fileset["justfile"] and "justfile" or "Justfile"
		local targets = parse_targets(root, name, 8)
		note(name .. (#targets > 0 and (": just " .. table.concat(targets, " / ")) or ""))
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
			note("package.json" .. (#bits > 0 and (": " .. table.concat(bits, " · ")) or ""))
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
			bits[#bits + 1] = "entry src/main.rs"
		elseif fileset["src/lib.rs"] then
			bits[#bits + 1] = "library src/lib.rs"
		end
		note("Cargo.toml" .. (#bits > 0 and (": " .. table.concat(bits, " · ")) or ""))
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
		note("go.mod" .. (#bits > 0 and (": " .. table.concat(bits, " · ")) or ""))
	end
	if fileset["pyproject.toml"] then
		local name, version
		for _, line in ipairs(read_lines(join(root, "pyproject.toml"), 200)) do
			name = name or line:match('^name%s*=%s*"(.-)"')
			version = version or line:match('^version%s*=%s*"(.-)"')
		end
		note("pyproject.toml" .. ((name or version) and (": " .. table.concat(
			vim.tbl_filter(function(x)
				return x ~= nil
			end, { name, version }),
			" "
		)) or ""))
	end
	if fileset["setup.py"] then
		note("setup.py")
	end
	if fileset["Dockerfile"] or fileset["docker-compose.yml"] or fileset["compose.yml"] then
		note("Docker: " .. table.concat(
			vim.tbl_filter(function(x)
				return fileset[x] and x or nil
			end, { "Dockerfile", "docker-compose.yml", "compose.yml" }),
			" · "
		))
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
		add(
			"cargo dependencies",
			toml_section_keys(root, "Cargo.toml", { dependencies = true, ["dev-dependencies"] = true }, 40)
		)
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
	{ ".editorconfig", "indent/line-ending conventions" },
	{ ".gitattributes", "git attributes" },
	{ "stylua.toml", "Lua formatter" },
	{ ".stylua.toml", "Lua formatter" },
	{ ".luacheckrc", "Lua lint" },
	{ "rustfmt.toml", "Rust formatter" },
	{ ".rustfmt.toml", "Rust formatter" },
	{ ".golangci.yml", "Go lint" },
	{ ".golangci.yaml", "Go lint" },
	{ ".prettierrc", "JS/TS formatter" },
	{ ".prettierrc.json", "JS/TS formatter" },
	{ "eslint.config.js", "JS/TS lint" },
	{ ".eslintrc", "JS/TS lint" },
	{ "AGENTS.md", "agent conventions" },
	{ "CLAUDE.md", "agent conventions" },
	{ "CONTRIBUTING.md", "contribution flow" },
	{ "CODE_OF_CONDUCT.md", "code of conduct" },
}

local function detect_conventions(root, fileset)
	local out = {}
	for _, item in ipairs(CONVENTION_FILES) do
		if fileset[item[1]] then
			out[#out + 1] = ("%s (%s)"):format(item[1], item[2])
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
		out[#out + 1] = "CI: " .. table.concat(ci, " · ")
	end
	local docs = {}
	for _, name in ipairs({ "README.md", "README.rst", "docs/", "doc/", "CONTRIBUTING.md", "AGENTS.md", "CHANGELOG.md" }) do
		if fileset[name] then
			docs[#docs + 1] = name
		end
	end
	if #docs > 0 then
		out[#out + 1] = "Docs: " .. table.concat(docs, " · ")
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
	stats = stats or { langs = {}, filelines = {}, code = 0, source = "unavailable", files = info.files }

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

return {
	collect = collect,
}
