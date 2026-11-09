-- https://probe.rs/docs/tools/debugger/
local project = require("dap_ext.project")

local M = {}

---@param bufnr number|nil
---@return table[]
local function build_configs(bufnr)
	if project.kind(bufnr) ~= "embedded" then
		return {}
	end
	local root = project.root(bufnr)
	local env = project.env_config(bufnr) or {}
	local prs = require("lib.probe_rs")

	-- chip 优先级：.nvim/dap.lua 显式声明 > .probe-rs-chip > 探头缓存 > 工程元数据
	-- 都拿不到就留空，probe-rs 会在 attach 时自己识别（TargetSelector::Auto）
	local chip = env.chip
	if not chip or chip == "" then
		chip = prs.resolve(root, "")
	end
	if chip == "" then
		chip = nil
	end

	local svdFile = env.svdFile
	if not svdFile then
		local found = vim.fn.glob(root .. "/*.svd", false, true)
		svdFile = found[1] and vim.fn.fnamemodify(found[1], ":p") or nil
	end

	-- programBinary 必须是字符串：nvim-dap 不会展开嵌套表里的函数
	local program = env.programBinary or prs.find_elf(root)

	return {
		{
			name = "probe-rs",
			type = "probe-rs-debug",
			request = "launch",
			cwd = root,
			chip = chip,
			flashingConfig = {
				flashingEnabled = program ~= nil,
				haltAfterReset = program ~= nil,
				formatOptions = { binaryFormat = "elf" },
			},
			coreConfigs = {
				{
					coreIndex = 0,
					programBinary = program,
					svdFile = svdFile,
					rttEnabled = true,
					rttChannelFormats = {
						{ channelNumber = 0, dataFormat = "String", showTimestamps = true },
						{ channelNumber = 1, dataFormat = "BinaryLE" },
					},
				},
			},
			env = { RUST_LOG = "info" },
			consoleLogLevel = "Console",
			runtimeExecutable = "probe-rs",
			runtimeArgs = { "dap-server" },
		},
	}
end

---@param dir string
---@return string[]
local function elf_candidates(dir)
	local out = {}
	local seen = {}
	for _, pat in ipairs({ "/build/**/*.elf", "/cmake-build-*/**/*.elf", "/target/**/*.elf", "/**/*.elf" }) do
		for _, f in ipairs(vim.fn.glob(dir .. pat, false, true)) do
			if not seen[f] then
				seen[f] = true
				out[#out + 1] = f
			end
		end
	end
	return out
end

---启动 probe-rs 调试：芯片缺失时手动选（写入 .probe-rs-chip），ELF 缺失时从候选里选
---@param bufnr number|nil
function M.launch(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local configs = build_configs(bufnr)
	local config = configs[1]
	if not config then
		vim.notify("probe-rs: 当前不是嵌入式项目（可在 .nvim/dap.lua 里设 kind = \"embedded\"）", vim.log.levels.WARN)
		return
	end
	local dap = require("dap")
	local prs = require("lib.probe_rs")

	local function start()
		local program = config.coreConfigs[1].programBinary
		if program then
			dap.run(config)
			return
		end
		local candidates = elf_candidates(config.cwd)
		vim.ui.select(candidates, { prompt = "选择要调试的 ELF" }, function(choice)
			if not choice then
				return
			end
			config.coreConfigs[1].programBinary = choice
			config.flashingConfig.flashingEnabled = true
			config.flashingConfig.haltAfterReset = true
			dap.run(config)
		end)
	end

	if config.chip then
		start()
		return
	end
	vim.notify("probe-rs: 未识别到芯片，手动选一个（会写入 .probe-rs-chip）", vim.log.levels.INFO)
	prs.pick_chip({ target = "project" }, function(chip)
		if not chip then
			return
		end
		config.chip = chip
		start()
	end)
end

---@param dap table
function M.setup(dap)
	-- 走 stdio：probe-rs 默认就是 single-session，不占端口、不会残留 server 进程
	dap.adapters["probe-rs-debug"] = {
		type = "executable",
		command = "probe-rs",
		args = { "dap-server" },
	}

	-- 动态 Provider（仅嵌入式项目参与）
	dap.providers.configs["probe-rs-debug"] = build_configs

	-- RTT listeners（保留原逻辑）
	local function log_to_file(msg)
		local f = io.open("probe-rs.log", "a")
		if f then
			f:write(msg .. "\n")
			f:close()
		end
	end

	dap.listeners.before["event_probe-rs-rtt-channel-config"]["plugins.nvim-dap-probe-rs"] = function(session, body)
		local msg = string.format(
			'%s: Opening RTT channel %d "%s"',
			os.date("%Y-%m-%dT%H:%M:%S"),
			body.channelNumber,
			body.channelName
		)
		vim.notify(msg, vim.log.levels.INFO)
		log_to_file(msg)
		session:request("rttWindowOpened", { body.channelNumber, true })
	end

	dap.listeners.before["event_probe-rs-rtt-data"]["plugins.nvim-dap-probe-rs"] = function(_, body)
		local msg = string.format("%s: RTT-Channel %d - %s", os.date("%Y-%m-%dT%H:%M:%S"), body.channelNumber, body.data)
		require("dap.repl").append(msg)
		log_to_file(msg)
	end

	dap.listeners.before["event_probe-rs-show-message"]["plugins.nvim-dap-probe-rs"] = function(_, body)
		local msg = string.format("%s: probe-rs message: %s", os.date("%Y-%m-%dT%H:%M:%S"), body.message)
		require("dap.repl").append(msg)
		log_to_file(msg)
	end

	require("dap.ext.vscode").type_to_filetypes["probe-rs-debug"] = { "rust", "c", "cpp" }

	vim.api.nvim_create_user_command("DapProbeRs", function()
		M.launch(0)
	end, { desc = "probe-rs 调试（缺芯片/ELF 时手动选）" })
	vim.keymap.set("n", "<leader>dE", function()
		M.launch(0)
	end, { desc = "[D]ap [E]mbedded probe-rs（自动/手动选芯片）" })
end

return M
