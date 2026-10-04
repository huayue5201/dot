-- lua/lsp-config/autocmds.lua
---@brief 所有 LSP 相关 autocmd 的注册中心
---@diagnostic disable: need-check-nil
local M = {}

local keys = require("lsp-config.keys")
local registry = require("lsp-config.registry")
local servers = require("lsp-config.servers")
local state = require("lsp-config.state")
local ctx = require("core.context")

-- 缓存调试状态，热路径不再反复读 vim.g
local debug_active = ctx.is_debug()

-- 存储当前缓冲区的状态
local buffer_states = {}

---------------------------------------------------------
-- 插入/选择模式禁用/启用诊断
---------------------------------------------------------
local function auto_diagnostic()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s", "i:n", "s:v" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function(args)
			local bufnr = args.buf
			local mode = vim.fn.mode()

			-- 如果调试处于活动状态，不做任何操作
			if debug_active then
				return
			end

			-- 诊断功能不需要检查客户端支持，因为 vim.diagnostic 是 Neovim 内置功能
			local diagnostics_enabled = state.get("lsp.diagnostics", bufnr)

			-- 只在诊断启用时才进行切换
			if diagnostics_enabled then
				if mode == "i" or mode == "s" or mode == "v" then
					-- 进入插入或选择模式
					vim.diagnostic.enable(false, { bufnr = bufnr })
					buffer_states[bufnr] = buffer_states[bufnr] or {}
					buffer_states[bufnr].diagnostics_enabled = false
				else
					-- 退出插入或选择模式
					vim.diagnostic.enable(true, { bufnr = bufnr })
					buffer_states[bufnr] = buffer_states[bufnr] or {}
					buffer_states[bufnr].diagnostics_enabled = true
				end
			end
		end,
	})
end

---------------------------------------------------------
-- 插入模式禁用内联提示
---------------------------------------------------------
local function auto_inlay_hint()
	-- 这个自动命令会在 LspAttach 中根据客户端能力有条件地启用
	local group = vim.api.nvim_create_augroup("UserLspInlayHint", { clear = true })

	vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
		group = group,
		desc = "LSP inlay hints 自动切换",
		callback = function(args)
			local bufnr = args.buf

			-- 该缓冲区未启用 inlay hint 自动切换
			if not buffer_states[bufnr] or not buffer_states[bufnr].inlay_hint_autocmd_enabled then
				return
			end

			-- 调试中不做任何操作
			if debug_active then
				return
			end

			local inlay_hint_enable = state.get("lsp.inlay_hints", bufnr)
			local is_insert = args.event == "InsertEnter"

			if inlay_hint_enable then
				vim.lsp.inlay_hint.enable(not is_insert, { bufnr = bufnr })
				buffer_states[bufnr] = buffer_states[bufnr] or {}
				buffer_states[bufnr].inlay_hint_enabled = not is_insert
			end
		end,
	})

	return group
end

---------------------------------------------------------
-- 应用当前缓冲区的设置
---------------------------------------------------------
local function apply_buffer_settings(bufnr)
	-- 调试中：强制禁用 LSP 功能
	if debug_active then
		vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
		vim.diagnostic.enable(false, { bufnr = bufnr })
		buffer_states[bufnr] = buffer_states[bufnr] or {}
		buffer_states[bufnr].inlay_hint_enabled = false
		buffer_states[bufnr].diagnostics_enabled = false
		return
	end

	local inlay_hint_enable = state.get("lsp.inlay_hints", bufnr)
	local diagnostics_enabled = state.get("lsp.diagnostics", bufnr)

	buffer_states[bufnr] = buffer_states[bufnr] or {}

	if inlay_hint_enable then
		vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
		buffer_states[bufnr].inlay_hint_enabled = true
	else
		vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
		buffer_states[bufnr].inlay_hint_enabled = false
	end

	if diagnostics_enabled then
		vim.diagnostic.enable(true, { bufnr = bufnr })
		buffer_states[bufnr].diagnostics_enabled = true
	else
		vim.diagnostic.enable(false, { bufnr = bufnr })
		buffer_states[bufnr].diagnostics_enabled = false
	end
end

---------------------------------------------------------
-- 处理设置变化
---------------------------------------------------------
local function setup_settings_watcher()
	-- 监听设置变化（nvim-store3 set 事件），跨项目实例自动接入
	state.subscribe(function(key, value)
		if debug_active then
			return
		end

		if key ~= "lsp.inlay_hints" and key ~= "lsp.diagnostics" then
			return
		end

		-- 兼容历史字符串值
		local enabled = value
		if type(value) == "string" then
			enabled = value == "on" or value == "active" or value == "enabled"
		end

		for _, client in ipairs(vim.lsp.get_clients()) do
			for _, bufnr in ipairs(client.attached_buffers or {}) do
				if key == "lsp.inlay_hints" then
					vim.lsp.inlay_hint.enable(enabled, { bufnr = bufnr })
					if buffer_states[bufnr] then
						buffer_states[bufnr].inlay_hint_enabled = enabled
					end
				else
					vim.diagnostic.enable(enabled, { bufnr = bufnr })
					if buffer_states[bufnr] then
						buffer_states[bufnr].diagnostics_enabled = enabled
					end
				end
			end
		end
	end)
end

---------------------------------------------------------
-- LspAttach
---------------------------------------------------------
local function setup_lsp_attach()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
		desc = "LSP 客户端附加到缓冲区时的配置",
		callback = function(args)
			local bufnr = args.buf
			local client = vim.lsp.get_client_by_id(args.data.client_id)

			-- 按键映射
			keys.attach(bufnr)

			-- 根据客户端能力启用 inlay hint 自动切换
			if client:supports_method("textDocument/inlayHint") then
				buffer_states[bufnr] = buffer_states[bufnr] or {}
				buffer_states[bufnr].inlay_hint_autocmd_enabled = true
			end

			-- Rust 宏展开预览（setup 内部自行守卫：仅 rust-analyzer + 支持 expandMacro）
			require("lsp-config.features.rust_macro_preview").setup(client, bufnr)

			-- LSP UTF-8 守卫：发送前扫描 params，发现非法 UTF-8 就替换为 U+FFFD 并告警。
			-- 背景：rust-analyzer 收到非法 UTF-8 报文会直接 run_session 报错退出
			-- （invalid utf-8 sequence ...），didOpen/didChange 又是广播给所有 client 的。
			-- 详见模块头部注释。幂等，多次 LspAttach 只会包一次。
			require("lsp-config.features.utf8_guard").setup(client)

			-- 应用当前缓冲区的持久化设置
			apply_buffer_settings(bufnr)

			-- 文档颜色
			if client:supports_method("textDocument/colorProvider") then
				vim.lsp.document_color.enable(true, {
					bufnr = bufnr,
				}, {
					style = "virtual",
				})
			end

			-- 链接编辑范围
			if client:supports_method("textDocument/linkedEditingRange") then
				vim.lsp.linked_editing_range.enable(true, { client_id = client.id, bufnr = bufnr })
			end

			-- workspace 级诊断（原生支持优先，否则用插件回退）
			if client:supports_method("workspace/diagnostic", bufnr) then
				vim.lsp.buf.workspace_diagnostics({ client_id = client.id })
			elseif vim.tbl_get(client.config, "filetypes") then
				local ok, wsdiag = pcall(require, "workspace-diagnostics")
				if ok then
					wsdiag.populate_workspace_diagnostics(client, bufnr)
				end
			end
		end,
	})
end

---------------------------------------------------------
-- 注册全部 autocmd
---------------------------------------------------------
function M.setup()
	-- 模式切换时临时开关诊断
	auto_diagnostic()

	-- inlay hint 自动切换组（默认不启用，LspAttach 里按能力开启）
	auto_inlay_hint()

	-- 设置变化监听器
	setup_settings_watcher()

	-- 调试状态变化时重新应用所有已知 buffer 的设置
	ctx.on_debug_change(function(active)
		debug_active = active
		for bufnr in pairs(buffer_states) do
			if vim.api.nvim_buf_is_valid(bufnr) then
				apply_buffer_settings(bufnr)
			end
		end
	end)

	-- FileType：按项目状态启停 server
	vim.api.nvim_create_autocmd("FileType", {
		desc = "根据文件类型启动或停止 LSP",
		pattern = registry.get_lsp_config("filetypes"),
		callback = function(args)
			servers.apply_for_buffer(args.buf)
		end,
	})

	-- LSP 客户端附加
	setup_lsp_attach()

	-- 缓冲区级 UTF-8 守卫：在非法字节进入 buffer 后就地修复，
	-- 保证 client 内部文档与 buffer 一致（避免 range 落在字符中间导致 server panic）。
	require("lsp-config.features.utf8_guard").setup_buffer_guard()

	-- 缓冲区卸载时清理状态
	vim.api.nvim_create_autocmd("BufUnload", {
		callback = function(args)
			buffer_states[args.buf] = nil
		end,
	})

	-- lsp/*.lua 改动后重载配置
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = { "lsp/*.lua", "after/lsp/*.lua" },
		group = vim.api.nvim_create_augroup("LSPConfigAutoReload", { clear = true }),
		callback = function()
			local _, count = registry.reload_lsp_configs()
			vim.notify(string.format("LSP configurations reloaded (%d configs total)", count), vim.log.levels.INFO)
		end,
	})
end

return M
