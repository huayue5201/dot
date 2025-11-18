local M = {}

local utils = require("lsp.lsp_utils")

vim.api.nvim_set_hl(0, "LspHighlight", { fg = "#fffff0", bold = true })

-- =========================================================
-- 动态 LSP Spinner（你给的字符序列）
-- =========================================================
local spinner_frames = { "", "", "", "", "", "" }
local spinner_index = 1
local spinner_active = false
local spinner_timer = vim.loop.new_timer()

local function spinner_start()
	if spinner_active then
		return
	end
	spinner_active = true

	spinner_timer:start(
		0,
		150,
		vim.schedule_wrap(function()
			spinner_index = (spinner_index % #spinner_frames) + 1
			vim.cmd("redrawstatus") -- 刷新状态栏
		end)
	)
end

local function spinner_stop()
	spinner_active = false
	spinner_timer:stop()
end

local function spinner_icon()
	if not spinner_active then
		return ""
	end
	return string.format("%-2s", spinner_frames[spinner_index]) -- 固定宽度 2
end

-- 自动监听 LSP 任务（LspProgress）
vim.api.nvim_create_autocmd("LspProgress", {
	callback = function(ev)
		local val = ev.data.params.value
		if val.kind == "begin" then
			spinner_start()
		elseif val.kind == "end" then
			spinner_stop()
		end
	end,
})

-- =========================================================
-- LSP 诊断级别配置
-- =========================================================
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

-- =========================================================
-- 获取 LSP 客户端显示
-- =========================================================
function M.lsp_clients()
	local buf_clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })

	if vim.tbl_isempty(buf_clients) then
		return "%#LspHighlight#󰼎 " .. "%*"
	end

	local ignore_list = {
		"null-ls",
		"ruff",
		"ruff_lsp",
		"eslint",
		"GitHub Copilot",
		"copilot",
		"lua_ls",
	}

	-- 找主客户端（未忽略的第一个）
	local main_client = buf_clients[1]
	for _, client in ipairs(buf_clients) do
		if not vim.tbl_contains(ignore_list, client.name) then
			main_client = client
			break
		end
	end

	local total = #buf_clients

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
	local icon = num_icons[total] or "󰿪"

	-- ⭐ 将动态 spinner 放在最前面
	local spin = spinner_icon()

	return string.format("%s %s. %s", "%#LspHighlight#" .. icon .. "%*", main_client.name, spin)
end

-- =========================================================
-- 获取诊断统计
-- =========================================================
function M.lsp_diagnostics()
	local diagnostics = vim.diagnostic.get(0)
	if #diagnostics == 0 then
		return ""
	end

	local counts = {
		[vim.diagnostic.severity.ERROR] = 0,
		[vim.diagnostic.severity.WARN] = 0,
		[vim.diagnostic.severity.INFO] = 0,
		[vim.diagnostic.severity.HINT] = 0,
	}

	for _, diag in ipairs(diagnostics) do
		counts[diag.severity] = counts[diag.severity] + 1
	end

	local parts = {}
	local order = {
		vim.diagnostic.severity.ERROR,
		vim.diagnostic.severity.WARN,
		vim.diagnostic.severity.INFO,
		vim.diagnostic.severity.HINT,
	}

	for _, sev in ipairs(order) do
		local count = counts[sev]
		if count > 0 then
			local data = DIAGNOSTIC_SEVERITY[sev]
			table.insert(parts, "%#" .. data.hl .. "#" .. data.icon .. count .. "%*")
		end
	end

	return table.concat(parts, " ")
end

-- =========================================================
-- 总 LSP 显示
-- =========================================================
function M.lsp()
	return M.lsp_clients()
end

return M
