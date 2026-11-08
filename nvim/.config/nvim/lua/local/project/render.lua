-- 项目概览：渲染（图标 + 分段 + 高亮），只依赖 util 的格式化函数
local util = require("local.project.util")

local num = util.num
local pct = util.pct

----------------------------------------------------------------------
-- 渲染
----------------------------------------------------------------------

-- 图标：文件/语言走 nvim-web-devicons（跟编辑器里其他地方一致），
-- 分节图标手写（devicons 没有「规模 / 活跃区」这种概念）
local ICON = {
	title = "",
	git = "", -- 拿不到 devicons 时的兜底
	scale = "",
	struct = "󰙅",
	active = "",
	build = "",
	deps = "󰏗",
	conventions = "",
	readme = "󰍔",
	tests = "",
	todo = "󰍔",
	hint = "󰈞",
}

local devicons ---@type table|false|nil
local function dev()
	if devicons == nil then
		local ok, mod = pcall(require, "nvim-web-devicons")
		devicons = ok and mod or false
	end
	return devicons or nil
end

--- 文件名 → icon, hl（拿不到就返回空串，渲染不受影响）
---@return string icon
---@return string|nil hl
local function file_icon(path)
	local d = dev()
	if not d or not path then
		return "", nil
	end
	local base = vim.fs.basename(path)
	local ext = base:match("%.([%w]+)$")
	local ok, icon, hl = pcall(d.get_icon, base, ext, { default = true })
	if ok and type(icon) == "string" and icon ~= "" then
		return icon, hl
	end
	return "", nil
end

-- 语言名 → 一个代表文件名，借 devicons 的图标与配色（不用再手抄一张图标表）
local LANG_FILE = {
	Lua = "a.lua",
	Markdown = "a.md",
	JSON = "a.json",
	TOML = "a.toml",
	YAML = "a.yaml",
	Shell = "a.sh",
	Python = "a.py",
	Rust = "a.rs",
	Go = "a.go",
	C = "a.c",
	["C++"] = "a.cpp",
	TypeScript = "a.ts",
	TSX = "a.tsx",
	JavaScript = "a.js",
	CSS = "a.css",
	SCSS = "a.scss",
	HTML = "a.html",
	["Vim script"] = "a.vim",
	Nix = "a.nix",
	SQL = "a.sql",
	TeX = "a.tex",
	Zig = "a.zig",
	Java = "a.java",
	Kotlin = "a.kt",
	Ruby = "a.rb",
	PHP = "a.php",
	Swift = "a.swift",
	["C#"] = "a.cs",
	Elixir = "a.ex",
	Haskell = "a.hs",
	OCaml = "a.ml",
	Scala = "a.scala",
	Dart = "a.dart",
	Vue = "a.vue",
	Svelte = "a.svelte",
	Text = "a.txt",
}

local function lang_icon(lang)
	local file = LANG_FILE[lang]
	if not file then
		return "", nil
	end
	return file_icon(file)
end

local ns = vim.api.nvim_create_namespace("project://overview")

--- 高亮组：全部 link 到 colorscheme 组，不写死颜色
local function ensure_hl()
	local groups = {
		ProjectIcon = "Title", -- 分节 / 标题前的图标
		ProjectDirIcon = "Directory", -- 目录图标
		ProjectNumber = "Number", -- 关键数字：行数 / 文件数 / 改动次数
		ProjectKey = "Constant", -- 关键取值：分支 / HEAD / license / 工具名
		ProjectPath = "String", -- 文件路径（真正要跳过去的对象）
		ProjectDim = "Comment", -- 次要信息：路径前缀 / 日期 / 占比
		ProjectOk = "DiagnosticOk", -- 干净 / 新鲜
		ProjectWarn = "DiagnosticWarn", -- 脏 / 陈旧 / 一堆 TODO
	}
	for name, link in pairs(groups) do
		vim.api.nvim_set_hl(0, name, { link = link, default = true })
	end
end

--- 距今天数（cs 格式 YYYY-MM-DD）；解析失败返回 nil
local function days_since(iso)
	local y, m, d = (iso or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not y then
		return nil
	end
	local then_time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
	if not then_time then
		return nil
	end
	return math.floor(os.difftime(os.time(), then_time) / 86400)
end

---@param content string|table 字符串，或 { "文本", { "文本", "HlGroup" }, ... } 的分段列表
---@param path string|nil 该行 gd 跳转的目标（相对 root）
local function render(data, full)
	local L, H, paths = {}, {}, {}
	local function add(content, path)
		local text, hls, col = "", {}, 0
		if type(content) == "string" then
			text = content
		else
			for _, item in ipairs(content) do
				local t, hl
				if type(item) == "string" then
					t = item
				else
					t, hl = item[1] or "", item[2]
				end
				if hl and #t > 0 then
					hls[#hls + 1] = { hl, col, col + #t }
				end
				text = text .. t
				col = col + #t
			end
		end
		local i = #L + 1
		L[i] = text
		H[i] = hls
		if path then
			paths[i] = path
		end
	end

	local function section(icon, text)
		add({ { icon .. " ", "ProjectIcon" }, text })
	end

	-- 数字 / 路径 / 键值的短写法，省得每行都手写 { text, "Group" }
	local function n(v)
		return { num(v), "ProjectNumber" }
	end
	local function p(v)
		return { v, "ProjectPath" }
	end
	local function k(v)
		return { v, "ProjectKey" }
	end
	local function dim(v)
		return { v, "ProjectDim" }
	end

	add({ { ICON.title .. " ", "ProjectIcon" }, { data.name, "Title" } })
	add("")
	-- 仓库新鲜度：最近一次提交距今多久（新仓库 / 停更仓库一眼可辨）
	local age = data.git and days_since(data.date)
	local date_hl = (age and age > 180) and "ProjectWarn" or "ProjectDim"
	if data.git then
		local git_icon, git_hl = file_icon(".gitignore")
		add({
			{ (git_icon ~= "" and git_icon or ICON.git) .. " ", git_hl or "ProjectIcon" },
			dim(data.root),
			"  ·  ",
			k(data.branch or "?"),
			" @ ",
			k(data.head or "?"),
			{ ("(%s)"):format(data.date or "unknown date"), date_hl },
		})
	else
		add({
			{ ICON.struct .. " ", "ProjectDirIcon" },
			dim(data.root),
			"  ·  not a git repository (counted directly from directories)",
		})
	end

	local meta = {}
	local function push(item)
		if #meta > 0 then
			meta[#meta + 1] = "  ·  "
		end
		meta[#meta + 1] = item
	end
	if data.license then
		push(k(data.license))
	end
	if #data.tags > 0 then
		push({
			(
				#data.tags > 1 and (num(#data.tags) .. " tags (latest " .. data.tags[1] .. ")")
				or (data.tags[1] .. " (1 tag)")
			),
			"ProjectKey",
		})
	end
	if data.git then
		if data.dirty > 0 then
			push({ ("%s uncommitted changes"):format(num(data.dirty)), "ProjectWarn" })
		else
			push({ "workspace clean", "ProjectOk" })
		end
	end
	if #meta > 0 then
		add(meta)
	end
	if data.readme_title and data.readme_title ~= data.name then
		add({
			{ ICON.readme .. " ", "ProjectIcon" },
			{ data.readme_title, "ProjectKey" },
		})
	end

	-- 规模
	add("")
	section(ICON.scale, "Scale")
	add({
		n(data.code),
		dim((" lines (%s)  ·  "):format(data.source)),
		n(#data.files),
		dim(" files"),
	})
	if #data.langs > 0 then
		local line = { "- Languages: " }
		for i, lang in ipairs(vim.list_slice(data.langs, 1, 6)) do
			if i > 1 then
				line[#line + 1] = " · "
			end
			local icon, hl = lang_icon(lang.name)
			if icon ~= "" then
				line[#line + 1] = { icon .. " ", hl }
			end
			line[#line + 1] = lang.name .. " "
			line[#line + 1] = n(lang.code)
			line[#line + 1] = dim(" " .. pct(lang.code, data.code))
		end
		add(line)
	end
	if #data.big > 0 then
		add("- Largest files:")
		for _, f in ipairs(vim.list_slice(data.big, 1, 5)) do
			local icon, hl = file_icon(f.path)
			add({
				"  - ",
				{ (icon ~= "" and (icon .. " ") or ""), hl },
				p(f.path),
				dim(" — "),
				n(f.lines),
				dim("L"),
			}, f.path)
		end
	end
	if full then
		add({
			{ ICON.tests .. " ", "ProjectIcon" },
			"Test files: ",
			n(data.tests),
			dim(" ("),
			{ pct(data.tests, #data.files), "ProjectNumber" },
			dim(")"),
		})
	end

	-- 结构
	if #data.structure > 0 then
		add("")
		section(ICON.struct, "Structure (by lines)")
		local shown = 0
		for _, d in ipairs(data.structure) do
			if shown >= 12 then
				break
			end
			shown = shown + 1
			add({
				"- ",
				{ ICON.struct .. " ", "ProjectDirIcon" },
				p(d.path or d.name),
				dim("  ·  "),
				n(d.files),
				dim(" files  ·  "),
				n(d.lines),
				dim("L"),
			}, d.path or d.name)
		end
		if #data.structure > shown then
			add({
				dim("- …plus "),
				n(#data.structure - shown),
				dim(" more directories"),
			})
		end
	end

	-- 活跃区（只看 git 历史，非 git 仓库没有这块）
	if not data.git then
		-- 跳过
	elseif #data.active > 0 then
		add("")
		section(ICON.active, "Active areas (changes in the last 90 days)")
		for _, f in ipairs(vim.list_slice(data.active, 1, full and 15 or 8)) do
			local icon, hl = file_icon(f.path)
			add({
				"- ",
				n(f.count),
				dim("×  "),
				{ (icon ~= "" and (icon .. " ") or ""), hl },
				p(f.path),
			}, f.path)
		end
	else
		add("")
		section(ICON.active, "Active areas")
		add("- no changes in the last 90 days (or only merges / empty history)")
	end

	-- 构建
	add("")
	section(ICON.build, "Build / entry points")
	if #data.build == 0 then
		add("- no Makefile / justfile / flake / manifest found; may be a plain script or docs repo")
	else
		for _, line in ipairs(data.build) do
			-- 「工具：recipe 列表」：工具名亮，recipe 暗，方便一眼定位入口
			local tool, rest = line:match("^(.-): (.*)$")
			if tool then
				add({ "- ", k(tool), dim(": "), dim(rest) })
			else
				add({ "- ", k(line) })
			end
		end
	end

	if full then
		add("")
		section(ICON.deps, "Dependencies")
		if #data.deps == 0 then
			add("- no dependencies parsed (no package.json / Cargo.toml / go.mod / requirements.txt)")
		else
			for _, dep in ipairs(data.deps) do
				local list = dep.list
				local shown = table.concat(vim.list_slice(list, 1, 12), ", ")
				local line = { "- ", k(dep.label), dim(": "), dim(shown) }
				if #list > 12 then
					line[#line + 1] = dim(" … total ")
					line[#line + 1] = n(#list)
					line[#line + 1] = dim(" items")
				end
				add(line)
			end
		end

		add("")
		section(ICON.conventions, "Conventions / tooling")
		if #data.conventions == 0 then
			add("- no convention files (.editorconfig / lint / CI / AGENTS.md)")
		else
			for _, line in ipairs(data.conventions) do
				local name, rest = line:match("^(.-) %((.*)%)$")
				if name then
					add({ "- ", k(name), dim(" (" .. rest .. ")") })
				else
					add("- " .. line)
				end
			end
		end
		if data.todo > 0 then
			add({
				{ ICON.todo .. " ", data.todo > 20 and "ProjectWarn" or "ProjectIcon" },
				"TODO / FIXME: ",
				n(data.todo),
				dim(" occurrences"),
			})
		end
	end

	add("")
	add({
		{ ICON.hint .. " ", "ProjectIcon" },
		{ "`t` " .. (full and "compact only" or "full version"), "ProjectDim" },
		dim(" · `A` ask AI with it · `C` put in chat · `q` close · `gd` jump · `r` re-collect"),
	})

	return L, H, paths
end

return {
	render = render,
	ensure_hl = ensure_hl,
	ns = ns,
}
