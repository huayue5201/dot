-- LSP 配置模块
local M = {}
local keymaps = require("lsp-config.lsp_keys")
local configs = require("lsp-config.setings")

-- 使用 nvim-store3（项目级）
local Store = require("nvim-store3").project()

---------------------------------------------------------
-- 插入/选择模式禁用/启用诊断
---------------------------------------------------------
local function auto_diagnostic()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s", "i:n" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()

			local diagnostics_enabled = Store:get("lsp.diagnostics")

			if diagnostics_enabled == "on" then
				vim.diagnostic.enable(false, { bufnr = bufnr })
			else
				vim.diagnostic.enable(false, { bufnr = bufnr })
			end

			vim.api.nvim_create_autocmd("ModeChanged", {
				pattern = { "i:n", "s:v" },
				once = true,
				desc = "离开插入/选择模式后重新启用诊断",
				callback = function()
					local current_buf = vim.api.nvim_get_current_buf()
					if vim.api.nvim_buf_is_valid(current_buf) then
						if diagnostics_enabled == "on" then
							vim.diagnostic.enable(true, { bufnr = current_buf })
						else
							vim.diagnostic.enable(false, { bufnr = current_buf })
						end
					end
				end,
			})
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
			local filter = { bufnr = args.buf }

			local inlay_hint_enable = Store:get("lsp.inlay_hints")

			if inlay_hint_enable == "on" then
				vim.lsp.inlay_hint.enable(false, filter)
			else
				vim.lsp.inlay_hint.enable(false, filter)
			end

			vim.api.nvim_create_autocmd("InsertLeave", {
				once = true,
				desc = "Re-enable lsp.inlay_hint when leaving insert mode",
				callback = function()
					if inlay_hint_enable == "on" then
						vim.lsp.inlay_hint.enable(true, filter)
					else
						vim.lsp.inlay_hint.enable(false, filter)
					end
				end,
			})
		end,
	})
end

---------------------------------------------------------
-- LSP Attach
---------------------------------------------------------
function M.setup()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
		desc = "LSP 客户端附加到缓冲区时的配置",
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)

			configs.diagnostic_config()
			keymaps.set_keymaps()

			-- 内联提示
			local inlay_hint_enable = Store:get("lsp.inlay_hints")
			vim.lsp.inlay_hint.enable(inlay_hint_enable == "on")

			-- 诊断
			local diagnostics_enabled = Store:get("lsp.diagnostics")
			vim.diagnostic.enable(diagnostics_enabled == "on")

			auto_diagnostic()
			auto_inlay_hint()

			vim.lsp.document_color.enable(true, 0, { style = "virtual" })

			if client:supports_method("textDocument/onTypeFormatting") then
				vim.lsp.on_type_formatting.enable(true, { client_id = client.id })
			end

			if client:supports_method("textDocument/foldingRange") then
				vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
			end

			if client:supports_method("textDocument/inlineCompletion") then
				vim.lsp.inline_completion.enable(true, { client_id = client.id })
			end

			if client:supports_method("textDocument/linkedEditingRange") then
				vim.lsp.linked_editing_range.enable(true, { client_id = client.id })
			end
		end,
	})
end

return M
