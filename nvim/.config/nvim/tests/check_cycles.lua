-- 顶层 require 的循环依赖检查。
--
--   nvim -l tests/check_cycles.lua
--
-- 只统计「模块加载期」的依赖，即行首（无缩进）的 require：
--
--   local sidebar = require("ui_menu.bar")   ← 算
--     return require("ui_menu").close_icon()     ← 不算（函数体里，调用期才解析）
--
-- 函数体内的 require 是延迟解析，构不成加载期的环；但它一旦被提到文件顶部，
-- 环就立刻成立。所以这里只保证「加载图无环」，并在一处留了提示。
--
-- 退出码：有环 1，无环 0。

local uv = vim.uv or vim.loop
local root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p") .. "lua"

-- 视为「本仓库自研模块」的顶层命名空间
local NAMESPACES = {
	"boot",
	"lib",
	"ui",
	"lsp_ext",
	"dap_ext",
	"feat",
	"fix",
	"local",
	"overseer",
	"resession",
	"vendor",
}

local function is_own(mod)
	local first = mod:match("^([^.]+)")
	for _, ns in ipairs(NAMESPACES) do
		if first == ns then
			return true
		end
	end
	return false
end

--- 收集 lua/ 下所有模块名 -> 文件路径
---@return table<string, string>
local function collect_modules()
	local mods = {}

	local function walk(dir)
		local handle = uv.fs_scandir(dir)
		if not handle then
			return
		end
		while true do
			local name, kind = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			local path = dir .. "/" .. name
			if kind == "directory" then
				walk(path)
			elseif name:sub(-4) == ".lua" then
				local rel = path:sub(#root + 2, -5):gsub("/", ".")
				mods[(rel:gsub("%.init$", ""))] = path
			end
		end
	end

	walk(root)
	return mods
end

--- 只取行首的 require（模块加载期执行的）
---@param path string
---@return string[]
local function top_level_requires(path)
	local out = {}
	local fd = io.open(path, "r")
	if not fd then
		return out
	end
	for line in fd:lines() do
		-- 缩进行 = 在函数体 / 条件块里，调用期才解析
		if line:match("^%S") then
			for mod in line:gmatch("require%s*%(?%s*[\"']([^\"']+)[\"']") do
				out[#out + 1] = mod
			end
		end
	end
	fd:close()
	return out
end

local mods = collect_modules()

local deps = {}
for mod, path in pairs(mods) do
	local set = {}
	for _, dep in ipairs(top_level_requires(path)) do
		if is_own(dep) and dep ~= mod and mods[dep] then
			set[dep] = true
		end
	end
	deps[mod] = set
end

-- Tarjan
local index, low, on_stack, stack, sccs = {}, {}, {}, {}, {}
local counter = 0

local function strongconnect(v)
	counter = counter + 1
	index[v], low[v] = counter, counter
	stack[#stack + 1] = v
	on_stack[v] = true

	for w in pairs(deps[v] or {}) do
		if not index[w] then
			strongconnect(w)
			low[v] = math.min(low[v], low[w])
		elseif on_stack[w] then
			low[v] = math.min(low[v], index[w])
		end
	end

	if low[v] == index[v] then
		local comp = {}
		while true do
			local w = table.remove(stack)
			on_stack[w] = false
			comp[#comp + 1] = w
			if w == v then
				break
			end
		end
		if #comp > 1 then
			table.sort(comp)
			sccs[#sccs + 1] = comp
		end
	end
end

local names = vim.tbl_keys(deps)
table.sort(names)
for _, mod in ipairs(names) do
	if not index[mod] then
		strongconnect(mod)
	end
end

local function count_files(mod)
	return #vim.split(table.concat(vim.fn.readfile(mods[mod]), "\n"), "\n")
end

if #sccs == 0 then
	print(("ok: %d 个模块，顶层 require 无环"):format(vim.tbl_count(mods)))
	os.exit(0)
end

print(("FAIL: %d 组顶层循环依赖"):format(#sccs))
for _, comp in ipairs(sccs) do
	print("")
	for _, mod in ipairs(comp) do
		print(("  %-45s %5d 行  %s"):format(mod, count_files(mod), mods[mod]:sub(#root + 2)))
	end
	print("  → " .. table.concat(comp, " ⇄ "))
end
os.exit(1)
