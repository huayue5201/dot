-- LSP 配置模块
local M = {}
local keymaps = require("lsp-config.lsp_keys")
local configs = require("lsp-config.setings")
local json_store = require("user.json_store")

-- 插入/选择模式禁用/启用诊断
local function auto_diagnostic()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s", "i:n" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			-- 获取诊断设置
			local diagnostics_enabled = json_store.get("lsp", "diagnostics")
			if diagnostics_enabled == "on" then
				-- 进入插入/选择模式时启用诊断
				vim.diagnostic.enable(false, { bufnr = bufnr })
			else
				-- 进入插入/选择模式时禁用诊断
				vim.diagnostic.enable(false, { bufnr = bufnr })
			end
			-- 离开插入/选择模式后重新启用诊断
			vim.api.nvim_create_autocmd("ModeChanged", {
				pattern = { "i:n", "s:v" },
				once = true,
				desc = "离开插入/选择模式后重新启用诊断",
				callback = function()
					local current_buf = vim.api.nvim_get_current_buf()
					if vim.api.nvim_buf_is_valid(current_buf) then
						-- 获取诊断设置
						if diagnostics_enabled == "on" then
							-- 离开模式后启用诊断
							vim.diagnostic.enable(true, { bufnr = current_buf })
						else
							-- 离开模式后禁用诊断
							vim.diagnostic.enable(false, { bufnr = current_buf })
						end
					end
				end,
			})
		end,
	})
end

-- 插入模式下禁用内联提示，离开插入模式重新启用
local function auto_inlay_hint()
	vim.api.nvim_create_autocmd("InsertEnter", {
		desc = "Disable lsp.inlay_hint when in insert mode",
		callback = function(args)
			local filter = { bufnr = args.buf }

			-- 获取内联提示设置
			local inlay_hint_enable = json_store.get("lsp", "inlay_hints")
			if inlay_hint_enable == "on" then
				-- 禁用内联提示
				vim.lsp.inlay_hint.enable(false, filter)
			else
				-- 禁用内联提示
				vim.lsp.inlay_hint.enable(false, filter)
			end

			-- 离开插入模式时重新启用内联提示
			vim.api.nvim_create_autocmd("InsertLeave", {
				once = true, -- 确保在离开插入模式时只触发一次
				desc = "Re-enable lsp.inlay_hint when leaving insert mode",
				callback = function()
					-- 获取内联提示设置
					if inlay_hint_enable == "on" then
						-- 启用内联提示
						vim.lsp.inlay_hint.enable(true, filter)
					else
						-- 禁用内联提示
						vim.lsp.inlay_hint.enable(false, filter)
					end
				end,
			})
		end,
	})
end

function M.setup()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
		desc = "LSP 客户端附加到缓冲区时的配置",
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			configs.diagnostic_config() -- 诊断ui
			keymaps.set_keymaps() -- 设置 LSP 按键映射

			local inlay_hint_enable = json_store.get("lsp", "inlay_hints")
			if inlay_hint_enable == "on" then
				vim.lsp.inlay_hint.enable(true)
			else
				vim.lsp.inlay_hint.enable(false)
			end

			local diagnostics_enabled = json_store.get("lsp", "diagnostics")
			if diagnostics_enabled == "on" then
				vim.diagnostic.enable(true)
			else
				vim.diagnostic.enable(false)
			end

			auto_diagnostic()
			auto_inlay_hint()

			vim.lsp.document_color.enable(true, 0, { style = "virtual" }) -- 启用文档颜色高亮

			---@diagnostic disable: need-check-nil
			--- 启用 插入模式 LSP 格式化
			if client:supports_method("textDocument/onTypeFormatting") then
				vim.lsp.on_type_formatting.enable(true, { client_id = client.id })
			end
			-- 启用 LSP 折叠
			if client:supports_method("textDocument/foldingRange") then
				vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
			end
			-- 启用内联补全,ai常用的建议虚拟文本
			if client:supports_method("textDocument/inlineCompletion") then
				vim.lsp.inline_completion.enable(true, { client_id = client.id })
			end
			-- 启用关联编辑范围
			if client:supports_method("textDocument/linkedEditingRange") then
				vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
			end

			-- if client:supports_method("textDocument/documentHighlight") then
			-- 	vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
			-- 		buffer = 0, -- 当前 buffer
			-- 		callback = function()
			-- 			vim.lsp.buf.document_highlight()
			-- 		end,
			-- 	})
			-- 	vim.api.nvim_create_autocmd("CursorMoved", {
			-- 		buffer = 0,
			-- 		callback = function()
			-- 			vim.lsp.buf.clear_references()
			-- 		end,
			-- 	})
			-- end
		end,
	})
end

return M
