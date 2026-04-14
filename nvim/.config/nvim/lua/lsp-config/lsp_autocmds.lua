--- File: /Users/lijia/dotfile/nvim/.config/nvim/lua/lsp-config/lsp_autocmds.lua
---@diagnostic disable: need-check-nil
-- LSP 配置模块
local M = {}
local keymaps = require("lsp-config.lsp_keys")
local configs = require("lsp-config.lsp_settings")

-- 使用 nvim-store3（项目级）
local Store = require("nvim-store3").project()

-- 确保有默认值
if Store:get("lsp.inlay_hints") == nil then
	Store:set("lsp.inlay_hints", "on")
end
if Store:get("lsp.diagnostics") == nil then
	Store:set("lsp.diagnostics", "on")
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
			if vim.g.dap_active then
				return
			end

			-- 诊断功能不需要检查客户端支持，因为 vim.diagnostic 是 Neovim 内置功能
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
	-- 这个自动命令会在 LspAttach 中根据客户端能力有条件地启用
	-- 所以这里只创建组，实际注册在 LspAttach 中
	local group = vim.api.nvim_create_augroup("UserLspInlayHint", { clear = true })

	-- 创建自动命令但先禁用
	vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
		group = group,
		desc = "LSP inlay hints 自动切换",
		callback = function(args)
			-- 这个回调会被调用，但我们可以通过检查 buffer_states 中的标志来决定是否执行
			local bufnr = args.buf

			-- 如果这个缓冲区没有启用 inlay hint 自动切换，直接返回
			if not buffer_states[bufnr] or not buffer_states[bufnr].inlay_hint_autocmd_enabled then
				return
			end

			-- 如果调试处于活动状态，不做任何操作
			if vim.g.dap_active then
				return
			end

			local inlay_hint_enable = Store:get("lsp.inlay_hints")
			local is_insert = args.event == "InsertEnter"

			if inlay_hint_enable == "on" then
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
	-- 如果调试处于活动状态，强制禁用 LSP 功能
	if vim.g.dap_active then
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
	-- 监听内联提示设置变化
	Store:on("lsp.inlay_hints", function(value)
		-- 如果调试处于活动状态，忽略设置变化
		if vim.g.dap_active then
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
		if vim.g.dap_active then
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

	-- 创建全局自动命令（诊断不需要客户端支持）
	auto_diagnostic()

	-- 创建 inlay hint 自动命令组（但默认不启用）
	local inlay_hint_group = auto_inlay_hint()

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

			-- 根据客户端能力启用 inlay hint 自动命令
			if client:supports_method("textDocument/inlayHint") then
				-- 标记这个缓冲区启用了 inlay hint 自动切换
				buffer_states[bufnr] = buffer_states[bufnr] or {}
				buffer_states[bufnr].inlay_hint_autocmd_enabled = true
			end

			-- 应用当前缓冲区的设置
			apply_buffer_settings(bufnr)

			-- 其他 LSP 功能设置
			if client:supports_method("textDocument/colorProvider") then
				vim.lsp.document_color.enable(true, {
					bufnr = bufnr,
				}, {
					style = "virtual",
				})
			end

			-- vim.lsp.codelens.enable(not vim.lsp.codelens.is_enabled())
			vim.lsp.codelens.enable(true)

			if client:supports_method("textDocument/onTypeFormatting") then
				vim.lsp.on_type_formatting.enable()
			end

			if client:supports_method("textDocument/foldingRange") then
				vim.wo.foldexpr = "v:lua:vim.lsp.foldexpr()"
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
