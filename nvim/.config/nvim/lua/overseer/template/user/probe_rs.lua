-- probe-rs 烧录/运行模板（https://probe.rs/docs/tools/probe-rs/）
--
-- 芯片名解析见 lua/lib/probe_rs.lua：`.probe-rs-chip` > 探头识别缓存 > 工程元数据
-- （.cargo/config.toml runner / Embed.toml / .ioc / sdkconfig / CMake MCU）。
-- 全都没有时 chip 留空 → probe-rs 自己走 TargetSelector::Auto，靠 ROM 表识别芯片。
-- 想让硬件侧识别一次并记住：跑「probe-rs info」任务，或 :ProbeRsDetectChip。

local lib = require("lib.probe_rs")
local TAG = require("overseer.constants").TAG

---@param params table
---@return string[]
local function probe_flags(params)
	local flags = {}
	if params.chip and params.chip ~= "" then
		vim.list_extend(flags, { "--chip", params.chip })
	end
	if params.probe and params.probe ~= "" then
		vim.list_extend(flags, { "--probe", params.probe })
	end
	vim.list_extend(flags, vim.split(params.extra or "", "%s+", { trimempty = true }))
	return flags
end

---@param elf string
---@return table
local function missing_elf(elf)
	return { cmd = { "echo", "没有找到 .elf / 可执行文件：请在参数里填写路径（当前：" .. elf .. "）" } }
end

---@type overseer.TemplateFileProvider
return {
	condition = { filetype = { "c", "cpp", "rust" } },
	generator = function(opts, cb)
		if vim.fn.executable("probe-rs") == 0 then
			return 'Command "probe-rs" not found（brew install probe-rs-tools / cargo binstall probe-rs-tools）'
		end

		local dir = opts.dir
		local elf = lib.find_elf(dir) or ""
		local chip, source = lib.resolve(dir, "")

		local chip_param = {
			type = "string",
			desc = "芯片名（留空 = probe-rs 自动识别）。当前来源：" .. source,
			default = chip,
			optional = true,
		}
		local probe_param = {
			type = "string",
			desc = "探头选择器 VID:PID:Serial（多块板时指定；同时决定芯片缓存槽位）",
			default = "",
			optional = true,
		}
		local extra_param = {
			type = "string",
			desc = "额外参数（如 --protocol jtag --speed 4000 --connect-under-reset）",
			default = "",
			optional = true,
		}
		local elf_param = {
			type = "string",
			desc = "要烧录的 ELF/可执行文件",
			default = elf,
		}

		cb({
			{
				name = "probe-rs run（烧录+运行+RTT 日志）",
				desc = "flash + reset + run，RTT/defmt 日志直接打在任务终端里；Ctrl-C 结束任务不会停板子",
				tags = { TAG.RUN },
				params = { elf = elf_param, chip = chip_param, probe = probe_param, extra = extra_param },
				builder = function(params)
					if params.elf == "" then
						return missing_elf(params.elf)
					end
					local cmd = { "probe-rs", "run", params.elf }
					vim.list_extend(cmd, probe_flags(params))
					return { cmd = cmd, cwd = dir, components = { "default" } }
				end,
			},
			{
				name = "probe-rs download（仅烧录，不运行）",
				desc = "烧完就退出；适合 CI / 只想验证 flash 算法是否匹配",
				tags = { TAG.BUILD },
				params = {
					elf = elf_param,
					chip = chip_param,
					probe = probe_param,
					verify = {
						type = "boolean",
						desc = "烧录后校验（--verify）",
						default = true,
						optional = true,
					},
					extra = extra_param,
				},
				builder = function(params)
					if params.elf == "" then
						return missing_elf(params.elf)
					end
					local cmd = { "probe-rs", "download", params.elf }
					vim.list_extend(cmd, probe_flags(params))
					if params.verify then
						vim.list_extend(cmd, { "--verify" })
					end
					return { cmd = cmd, cwd = dir, components = { "default" } }
				end,
			},
			{
				name = "probe-rs reset（复位芯片）",
				tags = { TAG.RUN },
				params = { chip = chip_param, probe = probe_param, extra = extra_param },
				builder = function(params)
					return {
						cmd = vim.list_extend({ "probe-rs", "reset" }, probe_flags(params)),
						cwd = dir,
						components = { "default" },
					}
				end,
			},
			{
				name = "probe-rs info（自动识别芯片并缓存）",
				desc = "连上探头读 ROM 表识别型号；识别成功后自动记住，下次烧录就不用填 chip",
				tags = { TAG.RUN },
				params = { probe = probe_param },
				builder = function(params)
					local cmd = { "probe-rs", "info" }
					if params.probe ~= "" then
						vim.list_extend(cmd, { "--probe", params.probe })
					end
					return { cmd = cmd, cwd = dir, components = { "default", "probe_rs_chip_cache" } }
				end,
			},
			{
				name = "probe-rs chip list（查芯片命名，输出可 / 搜索）",
				tags = { TAG.RUN },
				builder = function()
					return { cmd = { "probe-rs", "chip", "list" }, cwd = dir, components = { "default" } }
				end,
			},
		})
	end,
}
