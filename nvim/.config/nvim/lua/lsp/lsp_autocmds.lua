-- LSP 配置模块
local M = {}
local keymaps = require("lsp.lsp_keymaps")
local configs = require("lsp.config")

-- 插入/选择模式禁用/启用诊断
local function mode_changed_handler()
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s", "i:n" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			local diag_enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })
			if diag_enabled then
				-- 进入插入/选择模式时关闭诊断
				vim.diagnostic.enable(false, { bufnr = bufnr })
				-- 离开插入/选择模式后重新启用诊断，只启用一次自动命令
				vim.api.nvim_create_autocmd("ModeChanged", {
					pattern = { "i:n", "s:v" },
					once = true,
					desc = "离开插入/选择模式后重新启用诊断",
					callback = function()
						local current_buf = vim.api.nvim_get_current_buf()
						if vim.api.nvim_buf_is_valid(current_buf) then
							vim.diagnostic.enable(true, { bufnr = current_buf })
						end
					end,
				})
			end
		end,
	})
end

-- 插入模式下禁用内联提示，离开插入模式重新启用
local function inlay_hint_handler()
	vim.api.nvim_create_autocmd("InsertEnter", {
		desc = "Disable lsp.inlay_hint when in insert mode",
		callback = function(args)
			local filter = { bufnr = args.buf }
			local inlay_hint = vim.lsp.inlay_hint
			if inlay_hint.is_enabled(filter) then
				inlay_hint.enable(false, filter)
				vim.api.nvim_create_autocmd("InsertLeave", {
					once = true,
					desc = "Re-enable lsp.inlay_hint when leaving insert mode",
					callback = function()
						inlay_hint.enable(true, filter)
					end,
				})
			end
		end,
	})
end

function M.setup()
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
		desc = "LSP 客户端附加到缓冲区时的配置",
		callback = function(args)
			-- vim.lsp.stop_client(args.data.client_id, true)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			configs.diagnostic_config() -- 诊断ui
			inlay_hint_handler() -- 插入模式内联提示处理
			keymaps.set_keymaps() -- 设置 LSP 按键映射
			mode_changed_handler() -- 设置模式变化时禁用/启用诊断
			vim.lsp.document_color.enable(true, 0, { style = "virtual" }) -- 启用文档颜色高亮
			-- 启用 LSP 折叠
			if client:supports_method("textDocument/foldingRange") then
				local win = vim.api.nvim_get_current_win()
				vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
			end

			-- 启用内联提示
			if client:supports_method("textDocument/inlayHint") then
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
			end
		end,
	})

	-- LSP 从缓冲区分离时的清理
	vim.api.nvim_create_autocmd("LspDetach", {
		group = vim.api.nvim_create_augroup("LspStopAndUnmap", { clear = true }),
		desc = "LSP 客户端分离时停止客户端并移除键映射",
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client then
				-- 停止 LSP 客户端（当没有附加的缓冲区时）
				if not client.attached_buffers then
					client:stop()
				else
					for buf_id in pairs(client.attached_buffers) do
						if buf_id == args.buf then
							client:stop()
							break
						end
					end
				end
				-- 移除键映射
				keymaps.remove_keymaps()
			end
		end,
	})
end

vim.api.nvim_create_user_command("LspListActive", function()
	local lsps = require("lsp.lsp_utils").get_active_lsps(0)
	if #lsps == 0 then
		print("No active LSP clients for this buffer.")
		return
	end
	print("Active LSPs:")
	for _, lsp in ipairs(lsps) do
		print(string.format("- %s (root: %s)", lsp.name, lsp.root_dir or "nil"))
	end
end, { desc = "List active LSP clients for current buffer" })

-- 重启当前缓冲区的 LSP 客户端
-- local lsp_get = require("utils.lsp_utils")
-- function M.restart_lsp()
-- 	vim.lsp.stop_client(vim.lsp.get_clients(), true)
-- 	-- 延迟启动 LSP
-- 	vim.defer_fn(function()
-- 		local lsp_name = lsp_get.get_lsp_name()
--
-- 		vim.lsp.enable(lsp_name, true)
-- 		-- 更新 LSP 状态
-- 		require("utils.project_lsp_toggle").set_lsp_state(true)
-- 	end, 500)
-- end
--
-- -- 关闭lsp
-- function M.stop_lsp()
-- 	vim.lsp.stop_client(vim.lsp.get_clients(), true)
-- 	require("utils.project_lsp_toggle").set_lsp_state(false)
-- 	vim.schedule(function()
-- 		vim.cmd.redrawstatus()
-- 	end)
-- end

return M
