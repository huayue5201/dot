-- 项目概览：数据源解析（license / README / tokei / wc / 目录结构 / 活跃度 / recipe）
-- 这里全是纯函数：输入命令输出或文件内容，输出结构化的 data 片段，方便单独验证。
local util = require("local.project.util")

local join = util.join
local read_lines = util.read_lines
local is_noise = util.is_noise
local is_binary = util.is_binary
local lang_of = util.lang_of

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
			langs[#langs + 1] =
				{ name = lang, code = info.code, files = type(info.reports) == "table" and #info.reports or 0 }
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
		source = "tokei, excluding comments/blank lines",
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
		source = "wc -l (including comments and blank lines; language guessed by extension)",
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
			local key = line:match("^%s*([%w_%-]+)%s*=")
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

return {
	detect_license = detect_license,
	readme_title = readme_title,
	parse_tokei = parse_tokei,
	parse_wc = parse_wc,
	aggregate_structure = aggregate_structure,
	parse_active = parse_active,
	parse_targets = parse_targets,
	toml_section_keys = toml_section_keys,
}
