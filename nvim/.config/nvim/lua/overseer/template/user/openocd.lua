-- 嵌入式（OpenOCD / GDB）任务模板
-- openocd: https://openocd.org/doc/html/User-Interface.html
-- 出现条件：当前文件是 C/C++（避免在无关项目里刷屏）。
-- 配置文件查找顺序：向上找 .openocd.cfg / openocd.cfg；找不到就用参数里的
-- 默认 interface/target（默认按 STM32 + stlink 写，按自己板子改参数即可）。
-- ELF 查找顺序：build / cmake-build-* 下的 *.elf（优先），再退回项目根。
-- 推荐配合 nvim-dap-cortex-debug：先在任务里起 OpenOCD，再用 DAP 连接 :3333。

local TAG = require("overseer.constants").TAG

---@param opts overseer.SearchParams
---@return string|nil
local function find_cfg(opts)
	return vim.fs.find({ ".openocd.cfg", "openocd.cfg" }, {
		upward = true,
		type = "file",
		path = opts.dir,
	})[1]
end

---@param dir string
---@return string|nil
local function find_elf(dir)
	local patterns = {
		"build/**/*.elf",
		"cmake-build-*/**/*.elf",
		"Debug/**/*.elf",
		"Release/**/*.elf",
		"*.elf",
	}
	for _, pattern in ipairs(patterns) do
		local hits = vim.fn.glob(dir .. "/" .. pattern, false, true)
		-- 过滤出真实文件，且跳过 build 目录里的中间产物过多导致的误报
		for _, hit in ipairs(hits) do
			if vim.fn.filereadable(hit) == 1 then
				return hit
			end
		end
	end
	return nil
end

---把「项目 cfg」或「自定义 -f 参数」统一成 openocd 的 argv 前缀
---@param cfg string|nil
---@param args string
---@return string[]
local function openocd_args(cfg, args)
	if cfg then
		return { "-f", cfg }
	end
	return vim.split(args, "%s+", { trimempty = true })
end

local DEFAULT_ARGS = "-f interface/stlink.cfg -f target/stm32f4x.cfg"

---@type overseer.TemplateFileProvider
return {
	condition = { filetype = { "c", "cpp" } },
	cache_key = function(opts)
		return find_cfg(opts) or DEFAULT_ARGS
	end,
	generator = function(opts, cb)
		-- 项目隔离：OpenOCD 只属于嵌入式工程
		if require("dap_ext.project").kind(opts.dir, { quiet = true }) ~= "embedded" then
			cb({})
			return
		end
		if vim.fn.executable("openocd") == 0 then
			return 'Command "openocd" not found'
		end
		local cfg = find_cfg(opts)
		local cwd = cfg and vim.fs.dirname(cfg) or opts.dir
		local elf = find_elf(cwd)

		---@type overseer.TemplateDefinition[]
		local tasks = {
			{
				name = cfg and "OpenOCD: 启动调试服务器（项目 cfg）"
					or "OpenOCD: 启动调试服务器（默认 STM32/stlink）",
				tags = { TAG.RUN },
				builder = function()
					return {
						cmd = vim.list_extend({ "openocd" }, openocd_args(cfg, DEFAULT_ARGS)),
						cwd = cwd,
					}
				end,
			},
			{
				name = "OpenOCD: 启动调试服务器（自定义 -f 参数）",
				tags = { TAG.RUN },
				params = {
					args = {
						type = "string",
						desc = "openocd 参数（空格分隔，如 -f interface/cmsis-dap.cfg -f target/nrf52.cfg）",
						default = DEFAULT_ARGS,
					},
				},
				builder = function(params)
					return {
						cmd = vim.list_extend({ "openocd" }, vim.split(params.args, "%s+", { trimempty = true })),
						cwd = cwd,
					}
				end,
			},
			{
				name = "OpenOCD: 烧录 ELF（program verify reset exit）",
				tags = { TAG.BUILD },
				params = {
					elf = {
						type = "string",
						desc = "要烧录的 .elf（默认取 build 下第一个）",
						default = elf or "",
					},
					args = {
						type = "string",
						desc = "openocd 配置文件参数（留空则用项目 cfg / 默认 STM32-stlink）",
						default = "",
					},
				},
				builder = function(params)
					if params.elf == "" then
						return { cmd = { "echo", "没有找到 .elf：请先在参数里填写路径" }, cwd = cwd }
					end
					local base = params.args ~= "" and vim.split(params.args, "%s+", { trimempty = true })
						or openocd_args(cfg, DEFAULT_ARGS)
					local cmd = vim.list_extend({ "openocd" }, base)
					vim.list_extend(cmd, { "-c", "program " .. params.elf .. " verify reset exit" })
					return { cmd = cmd, cwd = cwd }
				end,
			},
		}

		if vim.fn.executable("arm-none-eabi-gdb") == 1 then
			table.insert(tasks, {
				name = "GDB: 连接 OpenOCD (:3333)",
				tags = { TAG.RUN },
				params = {
					elf = {
						type = "string",
						desc = "带调试符号的 .elf（默认取 build 下第一个）",
						default = elf or "",
					},
					port = {
						type = "integer",
						desc = "OpenOCD gdb_port（openocd.cfg 里没改就是 3333）",
						default = 3333,
					},
				},
				builder = function(params)
					if params.elf == "" then
						return { cmd = { "echo", "没有找到 .elf：请先在参数里填写路径" }, cwd = cwd }
					end
					return {
						cmd = {
							"arm-none-eabi-gdb",
							"-q",
							params.elf,
							"-ex",
							"target extended-remote :" .. params.port,
							"-ex",
							"monitor reset halt",
						},
						cwd = cwd,
					}
				end,
			})
		end

		cb(tasks)
	end,
}
