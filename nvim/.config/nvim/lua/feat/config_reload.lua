-- 不重启 nvim 应用配置改动（<leader>rl / :ConfigReload）
--
-- 本仓库没用 lazy.nvim，插件由 lua/boot/pack.lua（原生 vim.pack + 全 eager）加载，
-- 所以没有 :Lazy reload。这里按「当前 buffer 在配置里的位置」决定怎么重载：
--
--   1. lua/plugins/**.lua           → 重跑该 spec 里所有插件的 init/config/keys
--   2. lua/**（普通模块）            → 清掉该模块（init.lua 连同子模块）的 package.loaded，
--                                      再找 lua/plugins/ 里引用它的 spec，重跑这些 spec
--   3. boot/ 或 init.lua            → 启动期代码，只能重启（直接提示，不做半吊子重载）
--
-- 已知边界：
--   * 不是重新安装：新增插件、改 version/build 仍需重启；
--   * config 里注册的 autocmd 会再跑一遍（插件自己要用 clear 过的 augroup）；
--   * 已打开 buffer 里被删掉的 ft 键位不会自动回收（:e 或重开）；
--   * 普通模块若不在任何 spec 里被引用（例如 init.lua 里 setup 的 feat.*），只清缓存，
--     需要你自己重新触发入口（:lua require("...").setup()）。
local M = {}

local config_lua = vim.fs.joinpath(vim.fn.stdpath("config"), "lua")
-- 配置目录常是 dotfiles 的软链，比较前统一解析真身，否则 :p 出来的路径对不上
local config_lua_real = vim.uv.fs_realpath(config_lua) or config_lua

---@param path string
---@return string? rel 相对 config/lua 的路径，不在配置目录内则 nil
local function relpath_of(path)
	if path == nil or path == "" then
		return nil
	end
	path = vim.uv.fs_realpath(vim.fn.fnamemodify(path, ":p")) or vim.fn.fnamemodify(path, ":p")
	local prefix = config_lua_real .. "/"
	if path:sub(1, #prefix) ~= prefix then
		return nil
	end
	return path:sub(#prefix + 1)
end

---相对路径 → 模块名（lua/plugins/dap/x.lua → plugins.dap.x；a/init.lua → a）
---@param rel string
---@return string
local function module_of(rel)
	local mod = rel:gsub("%.lua$", ""):gsub("/init$", "")
	return (mod:gsub("/", "."))
end

---清掉模块本身和它的子模块缓存（改 a/init.lua 时子模块也要一起清）
---@param mod string
---@return integer cleared
local function clear_cache(mod)
	local prefix = mod .. "."
	local cleared = 0
	for name in pairs(package.loaded) do
		if name == mod or name:sub(1, #prefix) == prefix then
			package.loaded[name] = nil
			cleared = cleared + 1
		end
	end
	return cleared
end

---spec 文件列表（规则与 boot/pack.lua 的 collect() 保持一致：
---目录下有 init.lua 时，该目录本身算一个 spec，不再递归进去）
---@return string[] relpaths, string dir
local function spec_files()
	local dir = require("boot.pack").spec_dir()
	local files = {}
	local function walk(rel)
		local path = rel == "" and dir or vim.fs.joinpath(dir, rel)
		for entry, kind in vim.fs.dir(path) do
			local relpath = rel == "" and entry or (rel .. "/" .. entry)
			if kind == "file" and entry:match("%.lua$") then
				if entry ~= "init.lua" then
					files[#files + 1] = relpath
				end
			elseif kind == "directory" then
				if vim.fn.filereadable(vim.fs.joinpath(dir, relpath, "init.lua")) == 1 then
					files[#files + 1] = relpath
				else
					walk(relpath)
				end
			end
		end
	end
	walk("")
	return files, dir
end

---找引用该模块的 spec 文件：完整模块名和各级父模块都算（dap_ext/project.lua 的
---直接引用者可能只写 "dap_ext.project"，而真正把它接进 dap 的 spec 只写 "dap_ext"，
---两个都要重跑，所以取并集而不是命中即停）。
---单段父模块（lib / ui / feat 这种公共命名空间）命中太宽时跳过，避免重跑半个配置。
---@param mod string
---@return string[] relpaths, string? widest_prefix 最宽的命中前缀（用于提示）
local function find_owners(mod)
	local WIDE_LIMIT = 6
	local files, dir = spec_files()
	local segs = vim.split(mod, ".", { plain = true })
	local prefixes = { mod }
	for i = #segs - 1, 1, -1 do
		prefixes[#prefixes + 1] = table.concat(segs, ".", 1, i)
	end

	local contents = {}
	for _, rel in ipairs(files) do
		contents[rel] = table.concat(vim.fn.readfile(vim.fs.joinpath(dir, rel), "", 400), "\n")
	end

	local hits, seen = {}, {}
	local widest
	for _, prefix in ipairs(prefixes) do
		local level = {}
		for _, rel in ipairs(files) do
			local content = contents[rel]
			if content:find('"' .. prefix, 1, true) or content:find("'" .. prefix, 1, true) then
				level[#level + 1] = rel
			end
		end
		if #level > 0 and not (prefix:find("%.") == nil and #level > WIDE_LIMIT) then
			widest = prefix
			for _, rel in ipairs(level) do
				if not seen[rel] then
					seen[rel] = true
					hits[#hits + 1] = rel
				end
			end
		end
	end
	table.sort(hits)
	return hits, widest
end

local function reload_spec_files(rels)
	local pack = require("boot.pack")
	local reloaded, failed = {}, {}
	for _, rel in ipairs(rels) do
		-- 入参统一按「相对 lua/plugins/ 的路径」处理，补回模块前缀
		rel = rel:gsub("^plugins/", "")
		local ok, names = pack.reload_spec(module_of("plugins/" .. rel))
		if ok then
			vim.list_extend(reloaded, names)
		else
			failed[#failed + 1] = rel
		end
	end
	return reloaded, failed
end

---重载当前 buffer 对应的配置
function M.reload()
	local rel = relpath_of(vim.api.nvim_buf_get_name(0))
	if not rel then
		vim.notify("ConfigReload: 当前 buffer 不在配置目录（" .. config_lua .. "）内", vim.log.levels.WARN)
		return
	end

	if rel == "init.lua" or rel:match("^boot/") then
		vim.notify("ConfigReload: " .. rel .. " 是启动期代码，改完请重启 nvim", vim.log.levels.WARN)
		return
	end

	-- 1) spec 文件：直接重跑它声明的插件
	if rel:match("^plugins/") then
		local reloaded, failed = reload_spec_files({ rel })
		if #reloaded > 0 then
			vim.notify("已重跑插件配置: " .. table.concat(reloaded, ", "), vim.log.levels.INFO)
		elseif #failed > 0 then
			vim.notify("ConfigReload: " .. rel .. " 重跑失败（看 :messages）", vim.log.levels.ERROR)
		end
		return
	end

	-- 2) 普通模块：清缓存 + 重跑引用它的 spec
	local mod = module_of(rel)
	local owners, prefix = find_owners(mod)
	local cleared = clear_cache(mod)

	if #owners == 0 then
		vim.notify(
			("已清 %d 个模块缓存（%s）；没有插件 spec 引用它，重新触发入口即可"):format(
				cleared,
				mod
			),
			vim.log.levels.INFO
		)
		return
	end

	local reloaded, failed = reload_spec_files(owners)
	local parts = { ("已清 %d 个模块缓存（%s）"):format(cleared, mod) }
	if #reloaded > 0 then
		parts[#parts + 1] = "重跑插件配置: " .. table.concat(reloaded, ", ")
	end
	if #failed > 0 then
		parts[#parts + 1] = "失败: " .. table.concat(failed, ", ")
	end
	if prefix and prefix ~= mod then
		parts[#parts + 1] = ("（按父模块 %s 匹配）"):format(prefix)
	end
	vim.notify(table.concat(parts, "；"), #failed > 0 and vim.log.levels.ERROR or vim.log.levels.INFO)
end

function M.setup()
	vim.api.nvim_create_user_command("ConfigReload", function()
		M.reload()
	end, { desc = "重载当前配置（模块缓存 + 插件 config）" })
end

return M
