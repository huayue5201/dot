-- lua/lsp_ext/actions.lua
---@brief 可复用的 LSP 动作（供 keymaps / 命令调用，不含按键绑定）
local M = {}

local state = require("lsp_ext.state")

local d = vim.diagnostic

local live = require("lsp_ext.live_list")

local severity_order = {
	d.severity.ERROR,
	d.severity.WARN,
	d.severity.INFO,
	d.severity.HINT,
}

local function get_highest_severity(bufnr)
	bufnr = bufnr or 0
	local count = d.count(bufnr)

	for _, s in ipairs(severity_order) do
		if count[s] and count[s] > 0 then
			return s
		end
	end

	return nil
end

---------------------------------------------------------
-- 诊断跳转
---------------------------------------------------------
function M.jump_next()
	d.jump({
		count = vim.v.count1,
		severity = get_highest_severity(0), -- nil = all severities
	})
end

function M.jump_prev()
	d.jump({
		count = -vim.v.count1,
		severity = get_highest_severity(0),
	})
end

---------------------------------------------------------
-- 诊断 Quickfix / Loclist
---------------------------------------------------------
local WORKSPACE_QF_TITLE = "Project Diagnostics"

local function show_project_qflist(open)
	vim.diagnostic.setqflist({
		open = open,
		title = WORKSPACE_QF_TITLE,
		severity = { min = vim.diagnostic.severity.WARN },
	})
end

local function project_qf_win()
	local winid = vim.fn.getqflist({ winid = 1 }).winid
	if winid and winid > 0 and vim.api.nvim_win_is_valid(winid) then
		return winid
	end
end

local function project_qf_ours()
	return vim.fn.getqflist({ title = 1 }).title == WORKSPACE_QF_TITLE
end

--- 在列表窗口里再按 grd/grD 时，别拿 qf buffer 当目标（它没有诊断）
--- @return integer? win 一个普通文件窗口
local function resolve_file_win()
	local win = vim.api.nvim_get_current_win()
	if vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= "quickfix" then
		return win
	end
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(w)].buftype ~= "quickfix" then
			return w
		end
	end
end

--- 显式请求 workspace 级诊断（默认不再于 LspAttach 时扫描）
--- rust-analyzer 的 workspace/diagnostic 会触发全项目检查，代价很高，
--- 所以改成只由 `grD` 触发；结果分批返回，只要 qf 窗口开着就随诊断变化刷新。
--- 这样仍然是「一键看到项目诊断」，只是不再每次打开文件都扫一遍。
function M.open_all_diagnostics()
	local win = resolve_file_win()
	if not win then
		return
	end
	vim.api.nvim_set_current_win(win)
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "workspace/diagnostic" })

	if #clients == 0 then
		show_project_qflist(true)
	else
		for _, client in ipairs(clients) do
			vim.lsp.buf.workspace_diagnostics({ client_id = client.id })
		end
		show_project_qflist(true)
		vim.notify("workspace diagnostics: scanning...", vim.log.levels.INFO)
	end

	live.attach({
		kind = "quickfix",
		title = WORKSPACE_QF_TITLE,
		find_win = project_qf_win,
		is_ours = project_qf_ours,
		build = function()
			return vim.diagnostic.toqflist(vim.diagnostic.get(nil, { severity = { min = vim.diagnostic.severity.WARN } }))
		end,
	})
end

local BUF_LOC_TITLE = "Buffer Diagnostics"
local BUF_LOC_SEVERITY = { min = vim.diagnostic.severity.HINT }

---@brief `grd` 打开的 buffer 诊断 loclist 会随诊断变化就地刷新（不重开窗口、不抢焦点）。
--- 只维护一份：再次 grd 会重建状态；loclist 窗口或文件窗口关掉后自动注销。
local function find_buf_loc_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local info = vim.fn.getwininfo(win)[1]
		if info and info.loclist == 1 and vim.fn.getloclist(win, { title = 1 }).title == BUF_LOC_TITLE then
			return win
		end
	end
end

function M.open_buffer_diagnostics()
	local file_win = vim.api.nvim_get_current_win()
	if vim.bo.buftype == "quickfix" then
		-- 从列表窗口发起：用 loclist 记的来源窗口，而不是 qf buffer
		local src = vim.fn.getloclist(0, { filewinid = 1 }).filewinid
		if src and src > 0 and vim.api.nvim_win_is_valid(src) then
			file_win = src
		end
	end
	vim.api.nvim_set_current_win(file_win)
	local bufnr = vim.api.nvim_win_get_buf(file_win)

	vim.diagnostic.setloclist({
		open = true,
		title = BUF_LOC_TITLE,
		severity = BUF_LOC_SEVERITY,
	})
	live.attach({
		kind = "loclist",
		title = BUF_LOC_TITLE,
		srcwin = file_win,
		srcbuf = bufnr,
		find_win = find_buf_loc_window,
		is_ours = function()
			return find_buf_loc_window() ~= nil
		end,
		build = function(s)
			return vim.diagnostic.toqflist(vim.diagnostic.get(s.srcbuf, { severity = BUF_LOC_SEVERITY }))
		end,
	})
end

---------------------------------------------------------
-- 诊断 / 内联提示 开关（项目级持久化）
---------------------------------------------------------
function M.toggle_diagnostics(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local enabled = state.toggle("lsp.diagnostics", bufnr)
	vim.diagnostic.enable(enabled)
end

function M.toggle_inlay_hints(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local enabled = state.toggle("lsp.inlay_hints", bufnr)
	vim.lsp.inlay_hint.enable(enabled)
end

---------------------------------------------------------
-- 文档 / 复制 / 日志 / code lens
---------------------------------------------------------
function M.open_docs()
	require("lsp_ext.features.external_docs").open_docs()
end

function M.copy_diagnostics()
	require("lsp_ext.copy_diagnostics").copy_error_message()
end

function M.open_lsp_log()
	vim.cmd("tabnew " .. vim.lsp.log.get_filename())
end

---运行光标处 code lens（透镜由 features/code_lens.lua 自己渲染，直接执行它记录的那条命令）
function M.run_code_lens()
	if require("lsp_ext.features.code_lens").run_at_cursor() then
		return
	end
	-- 不退回 vim.lsp.codelens.run()：内置缓存会拿到 server 给的「空命令」透镜，
	-- 送进 Client:exec_cmd 就报 `does not support command ``` 且什么也不做。
	-- 服务器本来就不提供透镜（如 lua-language-server 的 codeLens 永远返回 null）时，
	-- 只提示一句，不自作主张用 references 之类去补。
	local bufnr = vim.api.nvim_get_current_buf()
	local names = {}
	for _, c in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		names[#names + 1] = c.name
	end
	vim.notify(
		string.format(
			"No runnable code lens on this line (%s)",
			#names > 0 and ("server: " .. table.concat(names, ", ")) or "no LSP client attached"
		),
		vim.log.levels.INFO
	)
end

return M
