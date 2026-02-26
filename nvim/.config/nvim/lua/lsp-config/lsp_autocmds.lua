--- File: /Users/lijia/dotfile/nvim/.config/nvim/lua/lsp-config/lsp_autocmds.lua
---@diagnostic disable: need-check-nil
-- LSP 配置模块
local M = {}
local keymaps = require("lsp-config.lsp_keys")
local configs = require("lsp-config.setings")

-- 使用 nvim-store3（项目级）
local Store = require("nvim-store3").project()

-- 确保有默认值
if Store:get("lsp.inlay_hints") == nil then
	Store:set("lsp.inlay_hints", "on")
end
if Store:get("lsp.diagnostics") == nil then
	Store:set("lsp.diagnostics", "on")
end
-- 初始化调试状态
if Store:get("dap.active") == nil then
	Store:set("dap.active", false)
end

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
			if Store:get("dap.active") then
				return
			end

			local diagnostics_enabled = Store:get("lsp.diagnostics")

			-- 只在诊断启用时才进行切换
			if diagnostics_enabled == "on" then
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
	vim.api.nvim_create_autocmd("InsertEnter", {
		desc = "Disable lsp.inlay_hint when in insert mode",
		callback = function(args)
			local bufnr = args.buf

			-- 如果调试处于活动状态，不做任何操作
			if Store:get("dap.active") then
				return
			end

			local inlay_hint_enable = Store:get("lsp.inlay_hints")

			if inlay_hint_enable == "on" then
				vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
				buffer_states[bufnr] = buffer_states[bufnr] or {}
				buffer_states[bufnr].inlay_hint_enabled = false
			end
		end,
	})

	vim.api.nvim_create_autocmd("InsertLeave", {
		desc = "Re-enable lsp.inlay_hint when leaving insert mode",
		callback = function(args)
			local bufnr = args.buf

			-- 如果调试处于活动状态，不做任何操作
			if Store:get("dap.active") then
				return
			end

			local inlay_hint_enable = Store:get("lsp.inlay_hints")

			if inlay_hint_enable == "on" then
				vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				buffer_states[bufnr] = buffer_states[bufnr] or {}
				buffer_states[bufnr].inlay_hint_enabled = true
			end
		end,
	})
end

---------------------------------------------------------
-- 应用当前缓冲区的设置
---------------------------------------------------------
local function apply_buffer_settings(bufnr)
	-- 如果调试处于活动状态，强制禁用 LSP 功能
	if Store:get("dap.active") then
		vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
		vim.diagnostic.enable(false, { bufnr = bufnr })
		buffer_states[bufnr] = buffer_states[bufnr] or {}
		buffer_states[bufnr].inlay_hint_enabled = false
		buffer_states[bufnr].diagnostics_enabled = false
		return
	end

	-- 正常模式下的设置
	local inlay_hint_enable = Store:get("lsp.inlay_hints")
	local diagnostics_enabled = Store:get("lsp.diagnostics")

	-- 初始化缓冲区状态
	buffer_states[bufnr] = buffer_states[bufnr] or {}

	-- 应用内联提示设置
	if inlay_hint_enable == "on" then
		vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
		buffer_states[bufnr].inlay_hint_enabled = true
	else
		vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
		buffer_states[bufnr].inlay_hint_enabled = false
	end

	-- 应用诊断设置
	if diagnostics_enabled == "on" then
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
	-- 监听调试状态变化（新增！）
	Store:on("dap.active", function(value)
		local clients = vim.lsp.get_clients()
		for _, client in ipairs(clients) do
			for _, bufnr in ipairs(client.attached_buffers or {}) do
				apply_buffer_settings(bufnr)
			end
		end
	end)

	-- 监听内联提示设置变化
	Store:on("lsp.inlay_hints", function(value)
		-- 如果调试处于活动状态，忽略设置变化
		if Store:get("dap.active") then
			return
		end

		local clients = vim.lsp.get_clients()
		for _, client in ipairs(clients) do
			for _, bufnr in ipairs(client.attached_buffers or {}) do
				if value == "on" then
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
					if buffer_states[bufnr] then
						buffer_states[bufnr].inlay_hint_enabled = true
					end
				else
					vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
					if buffer_states[bufnr] then
						buffer_states[bufnr].inlay_hint_enabled = false
					end
				end
			end
		end
	end)

	-- 监听诊断设置变化
	Store:on("lsp.diagnostics", function(value)
		-- 如果调试处于活动状态，忽略设置变化
		if Store:get("dap.active") then
			return
		end

		local clients = vim.lsp.get_clients()
		for _, client in ipairs(clients) do
			for _, bufnr in ipairs(client.attached_buffers or {}) do
				if value == "on" then
					vim.diagnostic.enable(true, { bufnr = bufnr })
					if buffer_states[bufnr] then
						buffer_states[bufnr].diagnostics_enabled = true
					end
				else
					vim.diagnostic.enable(false, { bufnr = bufnr })
					if buffer_states[bufnr] then
						buffer_states[bufnr].diagnostics_enabled = false
					end
				end
			end
		end
	end)
end

---------------------------------------------------------
-- LSP Attach
---------------------------------------------------------
function M.setup()
	-- 设置配置
	configs.diagnostic_config()

	-- 创建全局自动命令
	auto_diagnostic()
	auto_inlay_hint()

	-- 设置设置变化监听器
	setup_settings_watcher()

	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
		desc = "LSP 客户端附加到缓冲区时的配置",
		callback = function(args)
			local bufnr = args.buf
			local client = vim.lsp.get_client_by_id(args.data.client_id)

			-- 设置按键映射
			keymaps.set_keymaps(bufnr)

			-- 应用当前缓冲区的设置
			apply_buffer_settings(bufnr)

			-- 其他 LSP 功能设置
			vim.lsp.document_color.enable(true, bufnr, { style = "virtual" })

			if client:supports_method("textDocument/onTypeFormatting") then
				vim.lsp.on_type_formatting.enable(true, { client_id = client.id, bufnr = bufnr })
			end

			if client:supports_method("textDocument/foldingRange") then
				vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
			end

			if client:supports_method("textDocument/linkedEditingRange") then
				vim.lsp.linked_editing_range.enable(true, { client_id = client.id, bufnr = bufnr })
			end
		end,
	})

	-- 当缓冲区卸载时清理状态
	vim.api.nvim_create_autocmd("BufUnload", {
		callback = function(args)
			buffer_states[args.buf] = nil
		end,
	})
end

return M
