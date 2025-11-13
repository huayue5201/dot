local M = {}

local utils = require("lsp.utils")

vim.api.nvim_set_hl(0, "LspIcon", { fg = "#4876FF", bold = true })

-- ================================
-- LSP 诊断级别配置
-- ================================
local DIAGNOSTIC_SEVERITY = {
	[vim.diagnostic.severity.ERROR] = {
		icon = utils.icons.diagnostic.ERROR,
		hl = "DiagnosticError",
	},
	[vim.diagnostic.severity.WARN] = {
		icon = utils.icons.diagnostic.WARN,
		hl = "DiagnosticWarn",
	},
	[vim.diagnostic.severity.INFO] = {
		icon = utils.icons.diagnostic.INFO,
		hl = "DiagnosticInfo",
	},
	[vim.diagnostic.severity.HINT] = {
		icon = utils.icons.diagnostic.HINT,
		hl = "DiagnosticHint",
	},
}

--- 获取 LSP 客户端信息
function M.lsp_clients()
	local buf_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })

	if vim.tbl_isempty(buf_clients) then
		return "󰼎 "
	end

	-- 忽略列表，只是不显示名字，但数量要算
	local ignore_list = {
		"null-ls",
		"ruff",
		"ruff_lsp",
		"eslint",
		"GitHub Copilot",
		"copilot",
		"lua_ls",
	}

	-- 找主客户端（第一个不在 ignore 的）
	local main_client = buf_clients[1]
	for _, client in ipairs(buf_clients) do
		if not vim.tbl_contains(ignore_list, client.name) then
			main_client = client
			break
		end
	end

	local total_clients = #buf_clients -- 总数量，包括忽略的

	local num_icons = {
		[1] = "󰼏",
		[2] = "󰎨",
		[3] = "󰎫",
		[4] = "󰼒",
		[5] = "󰎯",
		[6] = "󰼔",
		[7] = "󰼕",
		[8] = "󰼖",
		[9] = "󰼗",
		[10] = "󰿪",
	}
	local icon = num_icons[total_clients] or "󰿪"

	return string.format("%s %s 󱞩", icon, main_client.name)
end

--- 获取 LSP 诊断信息
function M.lsp_diagnostics()
	local diagnostics = vim.diagnostic.get(0)
	if #diagnostics == 0 then
		return ""
	end

	-- 统计各严重级别的诊断数量
	local counts = {
		[vim.diagnostic.severity.ERROR] = 0,
		[vim.diagnostic.severity.WARN] = 0,
		[vim.diagnostic.severity.INFO] = 0,
		[vim.diagnostic.severity.HINT] = 0,
	}

	for _, diag in ipairs(diagnostics) do
		counts[diag.severity] = counts[diag.severity] + 1
	end

	-- 构建诊断组件
	local parts = {}
	local severity_order = {
		vim.diagnostic.severity.ERROR,
		vim.diagnostic.severity.WARN,
		vim.diagnostic.severity.INFO,
		vim.diagnostic.severity.HINT,
	}

	for _, severity in ipairs(severity_order) do
		local count = counts[severity]
		if count > 0 then
			local data = DIAGNOSTIC_SEVERITY[severity]
			table.insert(parts, "%#" .. data.hl .. "#" .. data.icon .. count .. "%*")
		end
	end

	return table.concat(parts, " ")
end

--- 获取完整的 LSP 状态
function M.lsp()
	return table.concat({
		M.lsp_clients(),
	})
end

return M
