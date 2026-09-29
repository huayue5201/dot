-- lua/dap-config/project.lua
---@brief DAP 项目类型判定 + 项目本地配置加载
-- 策略：默认按项目特征自动推断；允许项目根 <root>/.nvim/dap.lua 显式覆盖。
-- 返回 kind: "desktop" | "embedded"（后续可扩展更细的类型）。
--
-- 项目本地声明文件 <root>/.nvim/dap.lua 可返回：
--   {
--     kind = "embedded",              -- 覆盖自动推断（可选）
--     envConfig = {                   -- 嵌入式相关配置（可选）
--       chip = "STM32H750",
--       svdFile = "/path/to/x.svd",
--       configFiles = { "openocd.cfg" },
--     },
--   }
local M = {}

---@type table<string, "desktop"|"embedded">
local kind_cache = {}
---@type table<string, table|false>
local env_cache = {}
---@type table<string, table|false>
local local_cache = {}
---@type table<string, boolean>
local nudged = {}

local FALLBACK_MARKERS = { ".git", "Cargo.toml", "Makefile", "CMakeLists.txt" }

---定位项目根：优先 nvim-store3（已处理软链/尾斜杠），否则本地兜底
---@param bufnr number|nil
---@return string
function M.root(bufnr)
	local name = bufnr and vim.api.nvim_buf_get_name(bufnr) or ""
	if name == "" then
		name = vim.fn.getcwd()
	end

	local ok, Path = pcall(require, "nvim-store3.util.path")
	if ok and type(Path) == "table" and Path.project_root then
		local root = Path.project_root(name)
		if root then
			return root
		end
	end

	local dir = vim.fn.fnamemodify(name, ":p")
	if vim.fn.isdirectory(dir) ~= 1 then
		dir = vim.fn.fnamemodify(dir, ":h")
	end
	for _ = 1, 10 do
		for _, m in ipairs(FALLBACK_MARKERS) do
			if vim.fn.filereadable(dir .. "/" .. m) == 1 or vim.fn.isdirectory(dir .. "/" .. m) == 1 then
				return dir
			end
		end
		local parent = vim.fn.fnamemodify(dir, ":h")
		if parent == dir then
			break
		end
		dir = parent
	end
	return vim.fn.getcwd()
end

---读取项目本地声明文件 <root>/.nvim/dap.lua
---@param root string
---@return table|nil
local function load_local(root)
	local cached = local_cache[root]
	if cached ~= nil then
		return cached or nil
	end

	local file = root .. "/.nvim/dap.lua"
	if vim.fn.filereadable(file) ~= 1 then
		local_cache[root] = false
		return nil
	end

	local chunk, err = loadfile(file)
	if not chunk then
		vim.notify("DAP 项目配置解析失败: " .. tostring(err), vim.log.levels.WARN)
		local_cache[root] = false
		return nil
	end

	local ok, result = pcall(chunk)
	if not ok or type(result) ~= "table" then
		vim.notify("DAP 项目配置必须返回 table: " .. file, vim.log.levels.WARN)
		local_cache[root] = false
		return nil
	end

	local_cache[root] = result
	return result
end

---@param path string
---@param pattern string
---@return boolean
local function file_has(path, pattern)
	if vim.fn.filereadable(path) ~= 1 then
		return false
	end
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return false
	end
	for _, line in ipairs(lines) do
		if line:find(pattern) then
			return true
		end
	end
	return false
end

---明显表示嵌入式的文件
local STRONG_FILES = { "memory.x", "Embed.toml", "probe-rs.toml", "openocd.cfg", "defmt.x" }

---嵌入式的常见依赖名（Lua 模式）
local EMBEDDED_DEPS = {
	"cortex%-m",
	"cortex%-m%-rt",
	"embassy",
	"defmt",
	"panic%-probe",
	"probe%-rs",
	"stm32",
	"rp2040",
	"rp2350",
	"nrf5",
	"esp%-",
	"atsamd",
	"embedded%-hal",
	"rtic",
	"heapless",
}

---启发式判断是否嵌入式项目
---@param root string
---@return boolean
local function looks_embedded(root)
	for _, f in ipairs(STRONG_FILES) do
		if vim.fn.filereadable(root .. "/" .. f) == 1 then
			return true
		end
	end

	if #vim.fn.glob(root .. "/*.svd", false, true) > 0 then
		return true
	end

	for _, f in ipairs({ ".cargo/config.toml", ".cargo/config" }) do
		if file_has(root .. "/" .. f, "thumbv") or file_has(root .. "/" .. f, "probe%-rs") then
			return true
		end
	end

	for _, f in ipairs({ "rust-toolchain.toml", "rust-toolchain" }) do
		if file_has(root .. "/" .. f, "thumbv") or file_has(root .. "/" .. f, "riscv") then
			return true
		end
	end

	local cargo = root .. "/Cargo.toml"
	if vim.fn.filereadable(cargo) == 1 then
		local ok, lines = pcall(vim.fn.readfile, cargo)
		if ok then
			local content = table.concat(lines, "\n")
			for _, pat in ipairs(EMBEDDED_DEPS) do
				if content:find(pat) then
					return true
				end
			end
		end
	end

	for _, src in ipairs({ "src/main.rs", "src/lib.rs" }) do
		if file_has(root .. "/" .. src, "#!%[no_std%]") or file_has(root .. "/" .. src, "#!%[no_main%]") then
			return true
		end
	end

	return false
end

---当前缓冲区的项目类型
---@param bufnr number|nil
---@return "desktop"|"embedded"
function M.kind(bufnr)
	local root = M.root(bufnr)
	local cached = kind_cache[root]
	if cached then
		return cached
	end

	local local_cfg = load_local(root)
	local kind = (local_cfg and local_cfg.kind) or (looks_embedded(root) and "embedded" or "desktop")
	kind_cache[root] = kind

	-- 嵌入式项目且缺少本地声明时，提示一次可生成模板
	if not local_cfg and kind == "embedded" and not nudged[root] then
		nudged[root] = true
		vim.notify("检测到嵌入式项目，可用 :DapProjectInit 生成 .nvim/dap.lua", vim.log.levels.INFO)
	end

	return kind
end

---项目本地嵌入式配置（chip/svdFile/configFiles）；回退 vim.g.envConfig
---@param bufnr number|nil
---@return table|nil
function M.env_config(bufnr)
	local root = M.root(bufnr)
	if env_cache[root] == nil then
		local local_cfg = load_local(root)
		env_cache[root] = (local_cfg and local_cfg.envConfig) or false
	end
	local env = env_cache[root]
	if env then
		return env
	end
	return vim.g.envConfig or nil
end

---探测用于生成模板的信息
---@param root string
---@return { svdFile: string|nil, configFiles: string[], chip: string|nil }
local function detect_env(root)
	local result = { svdFile = nil, configFiles = {}, chip = nil }

	for _, sub in ipairs({ "", "svd", "hardware", "board", "bsp", ".svd", "config" }) do
		local dir = sub == "" and root or (root .. "/" .. sub)
		local found = vim.fn.glob(dir .. "/*.svd", false, true)
		if #found > 0 then
			result.svdFile = vim.fn.fnamemodify(found[1], ":p")
			break
		end
	end

	for _, f in ipairs({ "openocd.cfg", "openocd.cfg.lua" }) do
		if vim.fn.filereadable(root .. "/" .. f) == 1 then
			table.insert(result.configFiles, f)
		end
	end
	if #result.configFiles == 0 then
		local cfgs = vim.fn.glob(root .. "/*.cfg", false, true)
		if #cfgs > 0 then
			table.insert(result.configFiles, vim.fn.fnamemodify(cfgs[1], ":t"))
		end
	end

	return result
end

---生成模板内容
---@param kind string
---@param env table
---@return string
local function build_template(kind, env)
	local chip = env.chip and ("%q"):format(env.chip) or '"STM32xxxx"'
	local svd = env.svdFile and ("%q"):format(env.svdFile) or '"path/to/xxx.svd"'
	local configs = '{ "openocd.cfg" }'
	if #env.configFiles > 0 then
		local parts = {}
		for _, f in ipairs(env.configFiles) do
			parts[#parts + 1] = ("%q"):format(f)
		end
		configs = "{ " .. table.concat(parts, ", ") .. " }"
	end

	return table.concat({
		"-- <项目根>/.nvim/dap.lua",
		"-- 由 :DapProjectInit 生成，可按需修改。",
		"-- kind 省略时按项目特征自动推断。",
		"return {",
		("\tkind = %q, -- \"embedded\" | \"desktop\""):format(kind),
		"",
		"\t-- 嵌入式调试参数（OpenOCD / probe-rs 使用；desktop 项目可删）",
		"\tenvConfig = {",
		("\t\tchip = %s, -- probe-rs 需要"):format(chip),
		("\t\tsvdFile = %s, -- 外设寄存器描述"):format(svd),
		("\t\tconfigFiles = %s, -- OpenOCD 配置文件"):format(configs),
		"\t},",
		"}",
		"",
	}, "\n")
end

---为当前项目生成 .nvim/dap.lua 模板（已存在则直接打开）
---@param bufnr integer|nil
function M.init(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local root = M.root(bufnr)
	local file = root .. "/.nvim/dap.lua"

	if vim.fn.filereadable(file) == 1 then
		vim.notify("已存在项目 DAP 配置：" .. file, vim.log.levels.INFO)
		vim.cmd.edit(vim.fn.fnameescape(file))
		return
	end

	local kind = M.kind(bufnr)
	local content = build_template(kind, detect_env(root))

	vim.fn.mkdir(root .. "/.nvim", "p")
	local fd = io.open(file, "w")
	if not fd then
		vim.notify("无法写入：" .. file, vim.log.levels.ERROR)
		return
	end
	fd:write(content)
	fd:close()

	M.clear_cache()
	vim.notify("已生成项目 DAP 模板：" .. file, vim.log.levels.INFO)
	vim.cmd.edit(vim.fn.fnameescape(file))
end

vim.api.nvim_create_user_command("DapProjectInit", function()
	M.init(0)
end, { desc = "生成 .nvim/dap.lua 项目模板" })

---清空缓存（项目类型或本地声明变更时调用）
function M.clear_cache()
	kind_cache = {}
	env_cache = {}
	local_cache = {}
	nudged = {}
end

-- 相关文件写入后自动失效缓存
vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = { "Cargo.toml", "rust-toolchain.toml", "dap.lua" },
	callback = function()
		M.clear_cache()
	end,
})

return M
