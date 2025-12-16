local M = {}

-- 定义诊断图标
local icons = {
	ERROR = "",
	WARN = "",
	HINT = "",
	INFO = "",
}

-- 配置诊断显示
M.diagnostic_config = function()
	vim.diagnostic.config({
		-- 按严重程度排序
		severity_sort = true,
		-- 浮动窗口配置
		float = {
			source = "if_many",
			border = "solid",
		},
		-- signs 配置（文档支持 text/numhl/linehl）
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = icons.ERROR,
				[vim.diagnostic.severity.WARN] = icons.WARN,
				[vim.diagnostic.severity.HINT] = icons.HINT,
				[vim.diagnostic.severity.INFO] = icons.INFO,
			},
			numhl = {
				[vim.diagnostic.severity.ERROR] = "ErrorMsg",
				[vim.diagnostic.severity.WARN] = "WarningMsg",
			},
		},
		-- 下划线标记
		underline = true,
		-- 插入模式更新诊断
		update_in_insert = true,
	})
end

-- 全局配置
M.global_config = function()
	vim.lsp.config("*", {
		capabilities = {
			textDocument = {
				semanticTokens = {
					multilineTokenSupport = true,
				},
			},
		},
		root_markers = { ".git" },
	})
end

-- 根据文件类型启动 LSP
local lsp_get = require("lsp-config.lsp_utils")
local json_store = require("user.json_store")

M.lsp_Start = function()
	vim.api.nvim_create_autocmd("FileType", {
		desc = "根据文件类型启动或停止 LSP",
		pattern = lsp_get.get_lsp_config("filetypes"),
		callback = function()
			local lsp_names = lsp_get.get_lsp_by_filetype(vim.bo.filetype)
			for _, lsp_name in ipairs(lsp_names) do
				-- 获取 LSP 当前状态
				local lsp_state = json_store.get("lsp", lsp_name)

				if lsp_state == "inactive" then
					-- 停止 LSP 客户端
					vim.lsp.enable(lsp_name, false)
				else
					-- 启动 LSP 客户端
					vim.lsp.enable(lsp_name, true)
				end
			end
		end,
	})
end

return M
