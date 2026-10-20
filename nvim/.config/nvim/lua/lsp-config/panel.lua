-- lua/lsp-config/panel.lua
-- LSP 服务器控制面板（浮窗）
--
-- 交互（浮窗/按键/刷新）由 core.float-list 提供；本文件只负责行内容与行内动作。
--
-- 面板内容（针对当前 buffer）：
--   1) 功能开关（项目级持久化）：诊断 / 内联提示
--   2) 当前文件类型「已配置」的 LSP 服务器（来自 lsp/*.lua）
--   3) 当前 buffer「已附加」但不在配置里的 LSP（插件托管的，如 rustowl）—— 标 (外部)
--
-- 功能开关也保留了快捷键：<leader>rtd（诊断）/ <leader>rti（内联提示）。

local M = {}

local registry = require("lsp-config.registry")
local servers = require("lsp-config.servers")
local state = require("lsp-config.state")
local float_list = require("core.float-list")

local ICONS = { on = "✓ ", off = "○ " }

-- 功能开关：项目级持久化在 nvim-store3，切完立即作用到当前 buffer
local FEATURES = {
	{
		key = "lsp.diagnostics",
		label = "诊断",
		enabled = function(bufnr)
			return vim.diagnostic.is_enabled({ bufnr = bufnr })
		end,
		apply = function(on, bufnr)
			vim.diagnostic.enable(on, { bufnr = bufnr })
		end,
	},
	{
		key = "lsp.inlay_hints",
		label = "内联提示",
		enabled = function(bufnr)
			return vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
		end,
		apply = function(on, bufnr)
			vim.lsp.inlay_hint.enable(on, { bufnr = bufnr })
		end,
	},
}

local HELP = {
	{ "<CR>", "切换选中行（启用/停用）" },
	{ "R", "重启选中的 LSP" },
	{ "r", "刷新附加状态" },
	{ "j / k", "上下移动" },
	{ "1-9", "直接切换对应行" },
	{ "?", "显示/隐藏本帮助" },
	{ "q / <Esc> / <Tab> / <C-s>", "关闭面板" },
}

---------------------------------------------------------------------
-- 行构造
---------------------------------------------------------------------
local function build_rows(bufnr)
	local rows = {}

	-- 功能开关（诊断 / 内联提示）置顶，回车即切
	for _, feature in ipairs(FEATURES) do
		rows[#rows + 1] = { kind = "feature", feature = feature, name = feature.label }
	end

	-- 已配置（lsp/*.lua）的 server
	local configured = {}
	for _, name in ipairs(registry.get_lsp_by_filetype(vim.bo[bufnr].filetype)) do
		configured[name] = true
		rows[#rows + 1] = { kind = "server", name = name, configured = true }
	end

	-- 当前 buffer 已附加、但不在配置里的 server（插件托管，如 rustowl）
	local seen = {}
	for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if not configured[c.name] and not seen[c.name] then
			seen[c.name] = true
			rows[#rows + 1] = { kind = "server", name = c.name, configured = false }
		end
	end

	return rows
end

local function clients_for(name, bufnr)
	return vim.lsp.get_clients({ bufnr = bufnr, name = name })
end

local function row_enabled(row, bufnr)
	if row.kind == "feature" then
		return row.feature.enabled(bufnr)
	end
	if row.configured then
		return servers.is_enabled(row.name, bufnr)
	end
	-- 外部 server：只有附加即视为开启
	return #clients_for(row.name, bufnr) > 0
end

local function row_text(row, bufnr)
	local enabled = row_enabled(row, bufnr)
	local icon = enabled and ICONS.on or ICONS.off

	if row.kind == "feature" then
		return string.format("%s %-24s %s", icon, row.feature.label, enabled and "已开启" or "已关闭")
	end

	local clients = clients_for(row.name, bufnr)
	local attached = #clients > 0
	local status
	if row.configured then
		status = attached and "已附加" or "未附加"
	else
		status = attached and "已附加 (外部)" or "未附加 (外部)"
	end

	local root = ""
	for _, c in ipairs(clients) do
		local dir = c.config and c.config.root_dir
		if dir and dir ~= "" then
			root = "  " .. vim.fn.fnamemodify(dir, ":~")
			break
		end
	end

	return string.format("%s %-24s %s%s", icon, row.name, status, root)
end

---------------------------------------------------------------------
-- 行操作
---------------------------------------------------------------------
local function stop_external(name, bufnr)
	local clients = clients_for(name, bufnr)
	if #clients == 0 then
		vim.notify(name .. " 由插件托管，无法在此启用（请用其插件命令）", vim.log.levels.INFO)
		return
	end
	for _, c in ipairs(clients) do
		c:stop(true)
	end
	vim.notify("已停止外部 LSP: " .. name, vim.log.levels.INFO)
end

local function toggle_row(row, bufnr)
	if row.kind == "feature" then
		-- 写进项目 store（下次打开同项目保持），同时立即作用到当前 buffer
		local new = state.toggle(row.feature.key, bufnr)
		row.feature.apply(new, bufnr)
		vim.notify(string.format("%s：%s", row.feature.label, new and "开" or "关"), vim.log.levels.INFO)
		return
	end
	if row.configured then
		servers.set_enabled(row.name, not servers.is_enabled(row.name, bufnr), bufnr)
	else
		stop_external(row.name, bufnr)
	end
end

local function restart_row(row, bufnr)
	if not row or row.kind == "feature" then
		return
	end
	if row.configured then
		servers.restart_server(row.name, bufnr)
		vim.notify("重启 LSP: " .. row.name, vim.log.levels.INFO)
	else
		stop_external(row.name, bufnr)
	end
end

---------------------------------------------------------------------
-- 面板
---------------------------------------------------------------------
local panel

local function ensure_panel(bufnr)
	if panel then
		return panel
	end
	local icon_bytes = math.max(#ICONS.on, #ICONS.off)
	panel = float_list.new({
		title = " LSP 控制面板 ",
		width = 64,
		height = function(n)
			return n + 2
		end,
		max_height = 20,
		close_when_empty = false,
		rows = function()
			return build_rows(bufnr)
		end,
		text = function(row)
			return row_text(row, bufnr)
		end,
		highlights = function(row)
			return { { row_enabled(row, bufnr) and "DiagnosticOk" or "Comment", 0, icon_bytes } }
		end,
		guard = function(rows)
			if #rows == 0 then
				return "当前 buffer 没有可用的 LSP 服务器：" .. vim.bo[bufnr].filetype
			end
		end,
		enter = function(row, _, self)
			toggle_row(row, bufnr)
			self:refresh()
			vim.schedule(vim.cmd.redrawstatus)
		end,
		on_number = function(row, _, self)
			toggle_row(row, bufnr)
			self:refresh()
			vim.schedule(vim.cmd.redrawstatus)
		end,
		keymaps = {
			{
				"R",
				function(self)
					local idx = self:current()
					if idx then
						restart_row(self.items[idx], bufnr)
					end
				end,
			},
			{ "r", "refresh" },
		},
		help = HELP,
		help_title = " LSP 面板 · 按键帮助 ",
		close_keys = { q = "close", ["<Esc>"] = "close", ["<Tab>"] = "close", ["<C-s>"] = "close" },
		-- LSP 附加/断开是异步的：开关 server 后附加状态不会立刻变。
		refresh_events = { "LspAttach", "LspDetach" },
		refresh_augroup = "lsp_panel_refresh",
		refresh_filter = function(ev)
			return ev.buf == bufnr
		end,
	})
	return panel
end

function M.toggle()
	-- 面板关闭后重建，避免跨 buffer 复用旧的 bufnr
	if panel and not panel:is_open() then
		panel = nil
	end
	ensure_panel(vim.api.nvim_get_current_buf()):toggle()
end

---注册用户命令
function M.setup()
	vim.api.nvim_create_user_command("LspPanel", function()
		M.toggle()
	end, { desc = "LSP 服务器控制面板" })
end

return M
