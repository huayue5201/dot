-- LSP 核心配置模块
-- 包含诊断配置、按键映射、自动命令、LSP 客户端管理等功能
local M = {}

-- =============================================
-- 诊断配置
-- =============================================

function M.setup_diagnostics()
	vim.diagnostic.config({
		virtual_text = false, -- 设置false，诊断ui交给插件rachartier/tiny-inline-diagnostic.nvim
		severity_sort = true,
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = "󰅚 ",
				[vim.diagnostic.severity.WARN] = "󰀪 ",
				[vim.diagnostic.severity.HINT] = " ",
				[vim.diagnostic.severity.INFO] = " ",
			},
			linehl = { [vim.diagnostic.severity.ERROR] = "ErrorMsg" },
			numhl = { [vim.diagnostic.severity.WARN] = "WarningMsg" },
		},
		underline = true,
		update_in_insert = true,
	})
end

-- =============================================
-- 自动命令配置
-- =============================================

function M.setup_autocmds()
	-- =============================================
	-- 根据文件类型自动启动/停止 LSP
	-- =============================================
	local utils = require("lsp.utils")
	local supported_filetypes = utils.get_supported_filetypes()

	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("LspFileTypeAuto", { clear = true }),
		desc = "根据文件类型启动或停止 LSP",
		pattern = supported_filetypes,
		callback = function()
			local lsp_names = utils.get_lsp_name()

			if vim.g.lsp_enabled then
				-- 启用对应文件类型的 LSP
				for _, lsp_name in ipairs(lsp_names) do
					local success, err = pcall(vim.lsp.enable, lsp_name, true)
					if not success then
						vim.notify(string.format("LSP 启动失败 %s: %s", lsp_name, err), vim.log.levels.ERROR)
					end
				end
			else
				-- 停止对应文件类型的 LSP
				for _, lsp_name in ipairs(lsp_names) do
					pcall(vim.lsp.stop_client, lsp_name)
				end
			end
		end,
	})

	-- LSP 附加到缓冲区时的配置
	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
		desc = "LSP 客户端附加到缓冲区时的配置",
		callback = function(args)
			if not vim.g.lsp_enabled then
				vim.lsp.stop_client(args.data.client_id, true)
			else
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				M.setup_keymaps(args.buf) -- 设置 LSP 按键映射

				-- 启用文档颜色高亮
				vim.lsp.document_color.enable(true, 0, { style = "virtual" })

				-- 启用 LSP 折叠
				if client:supports_method("textDocument/foldingRange") then
					vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
				end

				-- 启用内联提示
				if client:supports_method("textDocument/inlayHint") then
					vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
				end
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
				client:stop()
				M.remove_keymaps(args.buf)
			end
		end,
	})

	-- 模式切换处理
	M.setup_mode_handlers()
end

-- =============================================
-- 模式切换处理
-- =============================================

function M.setup_mode_handlers()
	-- 插入/选择模式禁用/启用诊断
	vim.api.nvim_create_autocmd("ModeChanged", {
		pattern = { "n:i", "v:s", "i:n" },
		desc = "插入/选择模式禁用/启用诊断",
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			local diag_enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })
			if diag_enabled then
				vim.diagnostic.enable(false, { bufnr = bufnr })
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

	-- 插入模式下禁用内联提示
	vim.api.nvim_create_autocmd("InsertEnter", {
		desc = "插入模式禁用内联提示",
		callback = function(args)
			local filter = { bufnr = args.buf }
			local inlay_hint = vim.lsp.inlay_hint
			if inlay_hint.is_enabled(filter) then
				inlay_hint.enable(false, filter)
				vim.api.nvim_create_autocmd("InsertLeave", {
					once = true,
					desc = "离开插入模式重新启用内联提示",
					callback = function()
						inlay_hint.enable(true, filter)
					end,
				})
			end
		end,
	})
end

-- =============================================
-- 按键映射配置
-- =============================================

local keymaps = {
	{
		"<leader>lw",
		"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
		"列出工作区文件夹",
	},
	{
		"<leader>toi",
		"<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
		"打开/关闭内联提示",
	},
}

function M.setup_keymaps(bufnr)
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], {
			noremap = true,
			silent = true,
			desc = map[3],
			buffer = bufnr,
		})
	end
end

function M.remove_keymaps(bufnr)
	for _, map in ipairs(keymaps) do
		pcall(vim.keymap.del, "n", map[1], { buffer = bufnr })
	end
end

-- =============================================
-- 诊断工具函数
-- =============================================

-- 打开所有 buffer 的诊断（Quickfix 风格，适合全局排查）
function M.open_all_diagnostics()
	vim.diagnostic.setqflist({
		open = true,
		title = "项目诊断",
		severity = { min = vim.diagnostic.severity.WARN },
		format = function(d)
			return string.format(
				"[%s] %s (%s:%d)",
				vim.diagnostic.severity[d.severity],
				d.message,
				d.source or "?",
				d.lnum + 1
			)
		end,
	})
end

-- 仅当前 buffer 的诊断（Loclist 风格，适合局部修复）
function M.open_buffer_diagnostics()
	vim.diagnostic.setloclist({
		open = true,
		title = "缓冲区诊断",
		severity = { min = vim.diagnostic.severity.HINT },
		format = function(d)
			return string.format("[%s] %s (%s)", vim.diagnostic.severity[d.severity], d.message, d.source or "?")
		end,
	})
end

-- 复制光标处的错误信息（包括错误代码）
function M.copy_error_message()
	local row = unpack(vim.api.nvim_win_get_cursor(0)) - 1
	local diag = vim.diagnostic.get(0, { lnum = row })
	if #diag > 0 then
		local messages = {}
		for _, diagnostic in ipairs(diag) do
			local code = diagnostic.code or "无错误代码"
			local message = diagnostic.message or "无错误信息"
			table.insert(messages, message .. " [" .. code .. "]")
		end
		local all_messages = table.concat(messages, "\n")
		vim.fn.setreg("+", all_messages)
		print("错误信息已复制到剪贴板:\n" .. all_messages)
	else
		print("光标位置没有错误!")
	end
end

-- =============================================
-- LSP 客户端管理
-- =============================================

-- 重启当前缓冲区的 LSP 客户端
function M.restart_lsp()
	vim.lsp.stop_client(vim.lsp.get_clients(), true)
	vim.defer_fn(function()
		local utils = require("lsp.utils")
		local lsp_name = utils.get_lsp_name()
		vim.lsp.enable(lsp_name, true)
		require("lsp.manager").set_lsp_state(true) -- ✅ 修复：恢复状态设置
	end, 500)
end

-- 停止 LSP 客户端
function M.stop_lsp()
	vim.lsp.stop_client(vim.lsp.get_clients(), true)
	require("lsp.manager").set_lsp_state(false) -- ✅ 修复：恢复状态设置
	vim.schedule(function()
		vim.cmd.redrawstatus()
	end)
end

-- =============================================
-- 模块初始化
-- =============================================

function M.setup()
	M.setup_diagnostics()
end

return M
