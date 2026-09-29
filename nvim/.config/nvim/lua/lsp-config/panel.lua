-- lua/lsp-config/panel.lua
-- LSP 服务器控制面板（浮窗）
--
-- 交互参考 dap-config/exception-breakpoints.lua：
--   圆角浮窗、图标勾选、CR 切换、j/k 移动、数字跳转、R 重启、Tab/q/Esc 关闭
--
-- 面板内容（针对当前 buffer）：
--   1) 全局开关：诊断 / 内联提示
--   2) 当前文件类型「已配置」的 LSP 服务器（来自 lsp/*.lua）
--   3) 当前 buffer「已附加」但不在配置里的 LSP（插件托管的，如 rustowl）—— 标 (外部)

local M = {}

local registry = require("lsp-config.registry")
local servers = require("lsp-config.servers")
local state = require("lsp-config.state")
local actions = require("lsp-config.actions")

local ICONS = { on = "✓ ", off = "○ " }

local panel = { win = nil, buf = nil }

local function win_valid()
	return panel.win and vim.api.nvim_win_is_valid(panel.win)
end

local function close()
	if win_valid() then
		pcall(vim.api.nvim_win_close, panel.win, true)
	end
	panel.win, panel.buf = nil, nil
end

---------------------------------------------------------------------
-- 行构造 / 渲染
---------------------------------------------------------------------
local function build_rows(bufnr)
	local rows = {
		{ kind = "global", key = "lsp.diagnostics", label = "诊断 diagnostics" },
		{ kind = "global", key = "lsp.inlay_hints", label = "内联提示 inlay hints" },
	}

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
	if row.kind == "global" then
		return state.get(row.key, bufnr) ~= false
	end
	if row.configured then
		return servers.is_enabled(row.name, bufnr)
	end
	-- 外部 server：只有附加即视为开启
	return #clients_for(row.name, bufnr) > 0
end

---@return string text, boolean enabled
local function row_text(row, bufnr)
	local enabled = row_enabled(row, bufnr)
	local icon = enabled and ICONS.on or ICONS.off

	if row.kind == "global" then
		return string.format("%s %s", icon, row.label), enabled
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

	return string.format("%s %-24s %s%s", icon, row.name, status, root), enabled
end

local function render(buf, rows, bufnr)
	local lines = {}
	for i, row in ipairs(rows) do
		lines[i] = (row_text(row, bufnr))
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

	local icon_bytes = math.max(#ICONS.on, #ICONS.off)
	for i, row in ipairs(rows) do
		local _, enabled = row_text(row, bufnr)
		local hl = enabled and "DiagnosticOk" or "Comment"
		vim.api.nvim_buf_add_highlight(buf, -1, hl, i - 1, 0, icon_bytes)
	end
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
	if row.kind == "global" then
		if row.key == "lsp.diagnostics" then
			actions.toggle_diagnostics(bufnr)
		else
			actions.toggle_inlay_hints(bufnr)
		end
		return
	end

	if row.configured then
		servers.set_enabled(row.name, not servers.is_enabled(row.name, bufnr), bufnr)
	else
		stop_external(row.name, bufnr)
	end
end

---------------------------------------------------------------------
-- 打开 / 关闭
---------------------------------------------------------------------
function M.toggle()
	if win_valid() then
		close()
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local rows = build_rows(bufnr)
	if #rows <= 2 then
		vim.notify("当前 buffer 没有可用的 LSP 服务器：" .. vim.bo[bufnr].filetype, vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local width = 64
	local height = math.min(#rows + 2, 20)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		border = "rounded",
		style = "minimal",
		title = " LSP 控制面板 ",
		title_pos = "center",
	})

	vim.bo[buf].modifiable = true
	vim.bo[buf].bufhidden = "wipe"
	panel.win, panel.buf = win, buf

	local function cursor_line()
		return vim.api.nvim_win_get_cursor(win)[1]
	end

	local function refresh()
		if not win_valid() then
			return
		end
		rows = build_rows(bufnr)
		render(buf, rows, bufnr)
	end

	render(buf, rows, bufnr)

	local opts = { buffer = buf, nowait = true }

	-- CR：切换选中行
	vim.keymap.set("n", "<CR>", function()
		local row = rows[cursor_line()]
		if row then
			toggle_row(row, bufnr)
			render(buf, rows, bufnr)
			vim.schedule(vim.cmd.redrawstatus)
		end
	end, opts)

	-- R：重启选中行
	vim.keymap.set("n", "R", function()
		local row = rows[cursor_line()]
		if not row or row.kind ~= "server" then
			return
		end
		if row.configured then
			servers.restart_server(row.name, bufnr)
			vim.notify("重启 LSP: " .. row.name, vim.log.levels.INFO)
		else
			stop_external(row.name, bufnr)
		end
	end, opts)

	-- r：刷新（重算附加状态/根目录）
	vim.keymap.set("n", "r", refresh, opts)

	-- j/k：移动
	vim.keymap.set("n", "j", function()
		local c = cursor_line()
		if c < #rows then
			vim.api.nvim_win_set_cursor(win, { c + 1, 0 })
		end
	end, opts)
	vim.keymap.set("n", "k", function()
		local c = cursor_line()
		if c > 1 then
			vim.api.nvim_win_set_cursor(win, { c - 1, 0 })
		end
	end, opts)

	-- 数字键：直接切换对应行
	for i = 1, math.min(#rows, 9) do
		vim.keymap.set("n", tostring(i), function()
			local row = rows[i]
			if row then
				toggle_row(row, bufnr)
				render(buf, rows, bufnr)
			end
		end, opts)
	end

	vim.keymap.set("n", "q", close, opts)
	vim.keymap.set("n", "<Esc>", close, opts)
	vim.keymap.set("n", "<Tab>", close, opts)
	vim.keymap.set("n", "<C-s>", close, opts)
end

---注册用户命令
function M.setup()
	vim.api.nvim_create_user_command("LspPanel", function()
		M.toggle()
	end, { desc = "LSP 服务器控制面板" })
end

return M
