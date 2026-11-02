-- 项目概览：通用工具（路径拼接 / 行数格式化 / git 子进程 / 文件遍历 / 语言表）

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


--- 某个目录对应的项目根（不在 git 里就退回 cwd）
---@param root_opt string|nil
---@return string
local function resolve_root(root_opt)
	local root = root_opt
		or git_sync(vim.fn.getcwd(), { "rev-parse", "--show-toplevel" })
		or vim.fn.getcwd()
	return vim.fs.normalize(root)
end

return {
	resolve_root = resolve_root,
	notify = notify,
	join = join,
	split_lines = split_lines,
	git_sync = git_sync,
	run_parallel = run_parallel,
	read_lines = read_lines,
	num = num,
	pct = pct,
	is_noise = is_noise,
	is_binary = is_binary,
	walk_files = walk_files,
	lang_of = lang_of,
}
