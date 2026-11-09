-- probe-rs 芯片/ELF 解析（被 overseer 模板与 :ProbeRs* 命令共用）
--
-- 芯片名为什么会是难题：
--   probe-rs 的 --chip 决定 flash 算法与内存布局，猜错会烧到错误的地址。
--   所以这里按「确定性从高到低」取第一个命中的来源：
--     1. 项目根（向上）的 .probe-rs-chip 文件（一行芯片名，手工兜底）
--     2. probe-rs 自动识别结果缓存，按探头选择器分槽（一块板一个探头时最可靠，
--        换板=换探头 → 自动跟着换；同探头换板需重新 :ProbeRsDetectChip）
--     3. 工程元数据：.cargo/config.toml 的 runner、Embed.toml、STM32CubeMX .ioc、
--        ESP-IDF sdkconfig、CMake 的 MCU 变量
--     4. 都没有 → 返回空字符串，让 probe-rs 自己走 TargetSelector::Auto
--        （读 SWD/JTAG ROM 表 + JEP106 识别，和 `probe-rs info` 同一套逻辑）
--   ELF 自带的信息只有架构（Cortex-M4/M33…），没有厂商型号，所以不参与型号判断。

local M = {}

-- 缓存文件：~/.local/state/nvim/probe_rs_chips.json
-- 结构：{ probes = { ["<--probe 选择器 或 default>"] = "<chip>" } }
local function cache_path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "probe_rs_chips.json")
end

---@return table
local function load_cache()
	local path = cache_path()
	if vim.fn.filereadable(path) == 0 then
		return { probes = {} }
	end
	local content = table.concat(vim.fn.readfile(path), "\n")
	if content == "" then
		return { probes = {} }
	end
	local ok, data = pcall(vim.json.decode, content)
	if not ok or type(data) ~= "table" then
		return { probes = {} }
	end
	data.probes = type(data.probes) == "table" and data.probes or {}
	return data
end

---@param cache table
local function write_cache(cache)
	local ok, encoded = pcall(vim.json.encode, cache)
	if not ok then
		return
	end
	vim.fn.mkdir(vim.fs.dirname(cache_path()), "p")
	vim.fn.writefile({ encoded }, cache_path())
end

---@param probe string|nil
---@return string
local function probe_key(probe)
	if probe ~= nil and probe ~= "" then
		return probe
	end
	return "default"
end

---@param dir string
---@return string|nil
local ROOT_MARKERS = { ".git", ".cargo", "Cargo.toml", "CMakeLists.txt", "Makefile", "pyproject.toml", "sdkconfig" }

local function project_root(dir)
	return vim.fs.root(dir, ROOT_MARKERS)
end

---@param path string|nil
---@return string|nil
local function read_file(path)
	if not path or vim.fn.filereadable(path) == 0 then
		return nil
	end
	return table.concat(vim.fn.readfile(path), "\n")
end

---@param dir string
---@param names string[]
---@return string|nil
local function find_up(dir, names)
	return vim.fs.find(names, { upward = true, type = "file", path = dir })[1]
end

---@param s string|nil
---@return string|nil
local function trim(s)
	if not s then
		return nil
	end
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then
		return nil
	end
	return s
end

-- 1) 手工覆盖：向上找 .probe-rs-chip
---@param dir string
---@return string|nil
local function detect_override(dir)
	local path = find_up(dir, { ".probe-rs-chip" })
	local content = read_file(path)
	if not content then
		return nil
	end
	for line in content:gmatch("[^\r\n]+") do
		local chip = trim(line:gsub("#.*$", ""))
		if chip then
			return chip
		end
	end
	return nil
end

-- 3a) .cargo/config.toml: runner = 'probe-rs run --chip STM32F407VGTx'
---@param dir string
---@return string|nil
local function detect_cargo(dir)
	local cargo_dir = vim.fs.find(".cargo", { upward = true, type = "directory", path = dir })[1]
	if not cargo_dir then
		return nil
	end
	for _, name in ipairs({ "config.toml", "config" }) do
		local content = read_file(vim.fs.joinpath(cargo_dir, name))
		if content then
			local chip = content:match("%-%-chip[= ]+\"?([%w_%-%.]+)")
				or content:match("PROBE_RS_CHIP%s*=%s*\"?([%w_%-%.]+)")
			if chip then
				return chip
			end
		end
	end
	return nil
end

-- 3b) Embed.toml（probe-run 时代遗留，仍有项目在用）
---@param dir string
---@return string|nil
local function detect_embed(dir)
	local content = read_file(find_up(dir, { "Embed.toml" }))
	if not content then
		return nil
	end
	return content:match("^%s*chip%s*=%s*\"([^\"]+)\"")
end

-- 3c) STM32CubeMX 工程：*.ioc 里 Mcu.Name=STM32F407VGTx（与 probe-rs 命名一致）
---@param dir string
---@return string|nil
local function detect_ioc(dir)
	local ioc = vim.fs.find(function(name)
		return name:match("%.ioc$") ~= nil
	end, { upward = true, type = "file", path = dir, limit = 1 })[1]
	local content = read_file(ioc)
	if not content then
		return nil
	end
	return content:match("Mcu%.Name%s*=%s*([%w_%-%.]+)")
end

-- 3d) ESP-IDF：sdkconfig / sdkconfig.defaults 的 CONFIG_IDF_TARGET="esp32s3"
-- probe-rs 对 ESP32 系列支持有限（C3/S3/C6/H2/P4 等），芯片名与 IDF target 同名。
---@param dir string
---@return string|nil
local function detect_idf(dir)
	for _, name in ipairs({ "sdkconfig", "sdkconfig.defaults" }) do
		local content = read_file(find_up(dir, { name }))
		if content then
			local chip = content:match("CONFIG_IDF_TARGET%s*=%s*\"([%w_%-]+)\"")
			if chip then
				return chip
			end
		end
	end
	return nil
end

-- 3e) CMake：CMakeCache.txt 的 MCU 变量 / CMakeLists.txt 的 set(MCU ...)
---@param dir string
---@return string|nil
local function detect_cmake(dir)
	local cache = read_file(find_up(dir, { "CMakeCache.txt" }))
	if cache then
		local chip = cache:match("MCU[%w_]*:[%w_]+=([%w_%-%.]+)")
		if chip then
			return chip
		end
	end
	local lists = read_file(find_up(dir, { "CMakeLists.txt" }))
	if lists then
		return lists:match("set%s*%(%s*[%u_]*MCU%s+\"?([%w_%-%.]+)")
			or lists:match("%-D[%u_]*MCU=([%w_%-%.]+)")
	end
	return nil
end

local metadata_detectors = {
	{ detect_cargo, "'.cargo/config.toml' runner" },
	{ detect_embed, "'Embed.toml'" },
	{ detect_ioc, "STM32CubeMX .ioc" },
	{ detect_idf, "ESP-IDF sdkconfig" },
	{ detect_cmake, "CMake MCU 变量" },
}

---解析当前项目应该用的芯片名
---@param dir string 起始目录（通常是项目根）
---@param probe string|nil --probe 选择器，用于取对应探头的自动识别缓存
---@return string chip 空字符串 = 让 probe-rs 自动识别
---@return string source
function M.resolve(dir, probe)
	local override = detect_override(dir)
	if override then
		return override, ".probe-rs-chip"
	end

	local cached = load_cache().probes[probe_key(probe)]
	if cached and cached ~= "" then
		return cached, ("探头 %s 的识别缓存"):format(probe_key(probe))
	end

	for _, detector in ipairs(metadata_detectors) do
		local chip = detector[1](dir)
		if chip then
			return chip, detector[2]
		end
	end

	return "", "probe-rs 自动识别（TargetSelector::Auto）"
end

---写入「某个探头对应哪颗芯片」的缓存
---@param chip string
---@param probe string|nil
function M.save_probe_chip(chip, probe)
	chip = trim(chip)
	if not chip then
		return
	end
	local cache = load_cache()
	cache.probes[probe_key(probe)] = chip
	write_cache(cache)
end

---写项目级 .probe-rs-chip（手动选择后优先级最高）
---@param chip string
---@param dir string
---@return boolean ok
function M.save_project_chip(chip, dir)
	chip = trim(chip)
	local root = vim.fs.root(dir, ROOT_MARKERS)
	if not chip or not root then
		return false
	end
	vim.fn.writefile({ "# probe-rs --chip 手工覆盖（:ProbeRsPickChip 生成）", chip }, vim.fs.joinpath(root, ".probe-rs-chip"))
	return true
end

-- 芯片目录缓存：probe-rs chip list 输出里的所有具体型号
---@type string[]|nil
local catalog_cache

---@param cb fun(chips: string[]|nil, err: string|nil)
function M.chip_catalog(cb)
	if catalog_cache then
		cb(catalog_cache)
		return
	end
	if vim.fn.executable("probe-rs") == 0 then
		cb(nil, "probe-rs 未安装")
		return
	end
	vim.system({ "probe-rs", "chip", "list" }, { text = true, timeout = 30000 }, function(res)
		local chips = {}
		if res.code == 0 then
			for line in (res.stdout or ""):gmatch("[^\r\n]+") do
				-- 具体型号有缩进；家族行（如 STM32F4 Series）在行首，不收录
				if line:match("^%s+%S") then
					local name = trim(line)
					if name and name ~= "Variants:" and not name:match(":$") then
						table.insert(chips, name)
					end
				end
			end
		end
		if #chips > 0 then
			catalog_cache = chips
		end
		vim.schedule(function()
			if #chips == 0 then
				cb(nil, "probe-rs chip list 没有输出")
			else
				cb(chips)
			end
		end)
	end)
end

---手动从 chip list 里选芯片
---@param opts? { probe?: string, target?: "project"|"probe" }
---@param cb? fun(chip: string|nil, where: string|nil)
function M.pick_chip(opts, cb)
	opts = opts or {}
	M.chip_catalog(function(chips, err)
		if not chips then
			vim.notify("probe-rs: " .. tostring(err), vim.log.levels.WARN)
			if cb then
				cb(nil)
			end
			return
		end
		vim.ui.select(chips, { prompt = "手动选择 probe-rs 芯片", kind = "probe_rs_chip" }, function(choice)
			if not choice then
				return
			end
			local target = opts.target or "project"
			local where
			if target == "probe" or not M.save_project_chip(choice, vim.fn.getcwd()) then
				M.save_probe_chip(choice, opts.probe)
				where = "probe"
			else
				where = "project"
			end
			vim.notify(
				where == "project"
					and ("probe-rs: 已写入 .probe-rs-chip → %s"):format(choice)
					or ("probe-rs: 已写入探头缓存 → %s"):format(choice),
				vim.log.levels.INFO
			)
			if cb then
				cb(choice, where)
			end
		end)
	end)
end

---运行 `probe-rs info` 让硬件侧识别芯片，成功后写入缓存
---@param probe string|nil
---@param cb? fun(chip: string|nil, err: string|nil)
function M.detect_chip(probe, cb)
	if vim.fn.executable("probe-rs") == 0 then
		if cb then
			cb(nil, "probe-rs 未安装")
		end
		return
	end
	local cmd = { "probe-rs", "info" }
	if probe and probe ~= "" then
		vim.list_extend(cmd, { "--probe", probe })
	end
	vim.system(cmd, { text = true, timeout = 30000 }, function(res)
		local output = (res.stdout or "") .. "\n" .. (res.stderr or "")
		local chip = trim(output:match("Detected chip:%s*([^\r\n]+)"))
		if chip then
			M.save_probe_chip(chip, probe)
		end
		vim.schedule(function()
			if cb then
				cb(chip, chip and nil or "未能自动识别（探头未连接 / 芯片不受支持，可试 --verbose）")
			end
		end)
	end)
end

-- ELF 定位：C 项目找 *.elf；Rust 项目找 target/<triple>/{debug,release}/<可执行文件>
---@param dir string
---@param limit? integer
---@return string[]
local function glob_files(pattern, limit)
	local ret = {}
	for _, path in ipairs(vim.fn.glob(pattern, false, true)) do
		if vim.fn.filereadable(path) == 1 then
			table.insert(ret, path)
			if limit and #ret >= limit then
				break
			end
		end
	end
	return ret
end

---@param dir string
---@return string[]
local function rust_binaries(dir)
	local ret = {}
	for _, profile in ipairs({ "debug", "release" }) do
		for _, file in ipairs(vim.fn.glob(dir .. "/target/thumbv*/" .. profile .. "/*", false, true)) do
			local base = vim.fs.basename(file)
			local stat = (vim.uv or vim.loop).fs_stat(file)
			if
				stat
				and stat.type == "file"
				and vim.fn.executable(file) == 1
				and not base:match("%.d$")
				and not base:match("%.rlib$")
			then
				table.insert(ret, { path = file, mtime = stat.mtime.sec })
			end
		end
	end
	table.sort(ret, function(a, b)
		return a.mtime > b.mtime
	end)
	return vim.tbl_map(function(item)
		return item.path
	end, ret)
end

---@param dir string
---@return string|nil
function M.find_elf(dir)
	local root = project_root(dir) or dir
	if vim.fn.filereadable(vim.fs.joinpath(root, "Cargo.toml")) == 1 then
		local rust = rust_binaries(root)[1]
		if rust then
			return rust
		end
	end
	for _, pattern in ipairs({
		"/build/**/*.elf",
		"/cmake-build-*/**/*.elf",
		"/Debug/**/*.elf",
		"/Release/**/*.elf",
		"/*.elf",
	}) do
		local hits = glob_files(root .. pattern, 1)
		if hits[1] then
			return hits[1]
		end
	end
	return rust_binaries(root)[1]
end

---注册 :ProbeRsDetectChip / :ProbeRsChip
function M.setup()
	vim.api.nvim_create_user_command("ProbeRsDetectChip", function(opts)
		local probe = trim(opts.args) or ""
		vim.notify("probe-rs: 正在识别芯片…", vim.log.levels.INFO)
		M.detect_chip(probe, function(chip, err)
			if chip then
				vim.notify(
					("probe-rs: 检测到 %s（已缓存到探头 %s）"):format(chip, probe_key(probe)),
					vim.log.levels.INFO
				)
			else
				vim.notify("probe-rs: " .. tostring(err), vim.log.levels.WARN)
			end
		end)
	end, {
		nargs = "?",
		desc = "运行 probe-rs info 自动识别芯片并缓存（可选参数：--probe 选择器）",
		complete = function()
			return {}
		end,
	})
	vim.api.nvim_create_user_command("ProbeRsPickChip", function(opts)
		M.pick_chip({ target = opts.bang and "probe" or "project" })
	end, {
		bang = true,
		desc = "从 probe-rs chip list 手动选芯片：写项目 .probe-rs-chip；! 只写探头缓存",
	})
	vim.api.nvim_create_user_command("ProbeRsChip", function()
		local chip, source = M.resolve(vim.fn.getcwd(), "")
		vim.notify(
			("probe-rs: chip=%s（来源：%s）"):format(chip ~= "" and chip or "<自动>", source),
			vim.log.levels.INFO
		)
	end, { desc = "显示当前项目会被使用的 probe-rs 芯片名及来源" })
end

return M
