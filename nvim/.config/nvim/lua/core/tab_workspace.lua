-- 一个 tab 一个工作区
--   * 切 tab 自动隔离 buffer：每个 buffer 归属于它最近一次出现的 tab，
--     切到某个 tab 时只把属于它的 buffer 设为 listed（bufferline mode="buffers" 会跟着只显示这些）。
--   * 记忆每 tab cwd：用的是 Neovim 原生的 tcd（切 tab 自动生效），
--     resession 保存/恢复会话时也会带上每个 tab 的 cwd（resession 的 tab.cwd）。
--   * 会话归属持久化：见 lua/resession/extensions/tab_workspace.lua，隐藏 buffer 也能回到原 tab。
--   * 每 tab 的 LSP 生命周期：离开 tab 停掉只属于它的 LSP，进入 tab 再启动（省资源）。
--   * neo-tree 跟随 tab cwd：neo-tree 的 filesystem.bind_to_cwd 默认 true，监听 DirChanged；
--     切换带 tcd 的 tab 时会触发 DirChanged(match="tabpage")，因此 neo-tree 会自动换根，无需额外处理。
local M = {}

---@class TabWorkspaceConfig
---@field lsp_stop_on_leave boolean 离开 tab 时停掉只属于该 tab 的 LSP 客户端
---@field lsp_restart_on_enter boolean 进入 tab 时按需重启 LSP 客户端
---@field autoload_last_session boolean 启动时自动加载上次会话（_last）

---@type TabWorkspaceConfig
M.config = {
	lsp_stop_on_leave = true,
	lsp_restart_on_enter = true,
	autoload_last_session = false,
}

---@type table<integer, table<integer, boolean>> tabpage handle -> set of bufnrs
local ownership = {}

-- 我们自己改 buflisted 时置 true：Neovim 在把 buflisted 置 false 时会触发 BufDelete，
-- 需要忽略这个伪事件，否则会误把 buffer 从归属表里删掉。
local toggling = false

-- 本模块的 resession 扩展是否已经从会话里恢复了归属：若有则无需再从窗口布局重建
local imported = false

-- 上一个 tab（用于 alternate）
local last_tab

local GROUP = "TabWorkspace"
local AUTOSAVE_SESSION = "_last"

local function is_workspace_buf(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return false
	end
	if vim.bo[bufnr].buftype ~= "" then
		return false
	end
	if vim.api.nvim_buf_get_name(bufnr) == "" then
		return false
	end
	if vim.bo[bufnr].filetype == "neo-tree" then
		return false
	end
	return true
end

local function claim(tab, bufnr)
	if not is_workspace_buf(bufnr) then
		return
	end
	-- 移动语义：一个 buffer 只属于一个 tab（最近出现的地方）
	for _, set in pairs(ownership) do
		set[bufnr] = nil
	end
	ownership[tab] = ownership[tab] or {}
	ownership[tab][bufnr] = true
end

local function forget(bufnr)
	for _, set in pairs(ownership) do
		set[bufnr] = nil
	end
end

local function prune_closed_tabs()
	local valid = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		valid[tab] = true
	end
	for tab in pairs(ownership) do
		if not valid[tab] then
			ownership[tab] = nil
		end
	end
end

local function resession_loading()
	local ok, resession = pcall(require, "resession")
	return ok and resession.is_loading()
end

--- 该 tab 关联的所有 buffer（窗口里的 + 归属表里的）
---@param tab integer
---@return integer[]
local function tab_buffers(tab)
	local seen, out = {}, {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		local bufnr = vim.api.nvim_win_get_buf(win)
		if not seen[bufnr] then
			seen[bufnr] = true
			out[#out + 1] = bufnr
		end
	end
	for bufnr in pairs(ownership[tab] or {}) do
		if not seen[bufnr] then
			seen[bufnr] = true
			out[#out + 1] = bufnr
		end
	end
	return out
end

--- 被本模块停掉、等待重新进入 tab 时恢复的 LSP 服务名
local suspended = {}

--- 为 tab 中的 buffer 恢复已启用的、先前被停掉的服务
---@param tab integer
local function resume_tab_clients(tab)
	for name in pairs(suspended) do
		local ok, cfg = pcall(function()
			return vim.lsp.config[name]
		end)
		if not (vim.lsp.is_enabled(name) and ok and type(cfg) == "table") then
			suspended[name] = nil
		else
			local started = false
			for _, bufnr in ipairs(tab_buffers(tab)) do
				if
					vim.api.nvim_buf_is_valid(bufnr)
					and vim.bo[bufnr].buftype == ""
					and #vim.lsp.get_clients({ bufnr = bufnr, name = name }) == 0
					and (not cfg.filetypes or vim.tbl_contains(cfg.filetypes, vim.bo[bufnr].filetype))
				then
					if pcall(vim.lsp.start, cfg, { bufnr = bufnr }) then
						started = true
					end
				end
			end
			if started then
				suspended[name] = nil
			end
		end
	end
end

--- 切换 tab 后同步 LSP：停掉当前 tab 不再需要的 client，再为需要的 buffer 启动
---@param tab integer
local function sync_lsp(tab)
	if not vim.api.nvim_tabpage_is_valid(tab) then
		return
	end
	local current = {}
	for _, bufnr in ipairs(tab_buffers(tab)) do
		current[bufnr] = true
	end
	if M.config.lsp_stop_on_leave then
		for _, client in ipairs(vim.lsp.get_clients()) do
			local used = false
			for bufnr in pairs(client.attached_buffers or {}) do
				if current[bufnr] then
					used = true
					break
				end
			end
			if not used then
				suspended[client.name] = true
				pcall(function()
					client:stop(true)
				end)
			end
		end
	end
	if M.config.lsp_restart_on_enter then
		resume_tab_clients(tab)
	end
end

--- 按「当前 tab 的归属」重设所有 buffer 的 buflisted
function M.relist()
	prune_closed_tabs()
	if resession_loading() then
		return
	end
	local owned = ownership[vim.api.nvim_get_current_tabpage()] or {}
	toggling = true
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if is_workspace_buf(bufnr) then
			vim.bo[bufnr].buflisted = owned[bufnr] == true
		end
	end
	toggling = false
end

--- 导出每 tab 的归属（buffer 名），供 resession 扩展保存进会话文件
---@return table<string, string[]>
function M.export()
	local out = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local set = ownership[tab]
		if set then
			local names = {}
			for bufnr in pairs(set) do
				if vim.api.nvim_buf_is_valid(bufnr) then
					local name = vim.api.nvim_buf_get_name(bufnr)
					if name ~= "" then
						names[#names + 1] = name
					end
				end
			end
			if #names > 0 then
				out[tostring(vim.api.nvim_tabpage_get_number(tab))] = names
			end
		end
	end
	return out
end

--- 从会话里导出的归属恢复到当前 tabpages（resession 扩展调用）
---@param map? table<string, string[]>
function M.import(map)
	if type(map) ~= "table" or next(map) == nil then
		return
	end
	local byname = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(bufnr)
		if name ~= "" then
			byname[name] = bufnr
			byname[vim.fn.fnamemodify(name, ":p")] = bufnr
		end
	end
	local restored = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local names = map[tostring(vim.api.nvim_tabpage_get_number(tab))]
		if names then
			restored[tab] = {}
			for _, name in ipairs(names) do
				local bufnr = byname[name] or byname[vim.fn.fnamemodify(name, ":p")]
				if bufnr then
					restored[tab][bufnr] = true
				end
			end
		end
	end
	ownership = restored
	imported = true
	M.relist()
end

--- 从当前窗口布局重建归属（会话加载后调用）
function M.rebuild()
	ownership = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
			if vim.api.nvim_win_get_config(win).relative == "" then
				claim(tab, vim.api.nvim_win_get_buf(win))
			end
		end
	end
	M.relist()
end

--- 设置当前 tab 的工作区根目录（neo-tree 会经 DirChanged 自动跟随）
---@param dir? string
function M.set_root(dir)
	dir = vim.fn.expand(dir or vim.fn.getcwd())
	vim.cmd.tcd({ args = { dir } })
end

--- 交互式设置当前 tab 根目录
function M.prompt_root()
	local cur = vim.fn.getcwd()
	vim.ui.input({ prompt = "工作区根目录: ", default = cur, completion = "dir" }, function(input)
		if input and input ~= "" then
			M.set_root(input)
		end
	end)
end

--- 保存当前会话（若有）
function M.save_session()
	local ok, resession = pcall(require, "resession")
	if not ok then
		return
	end
	local current = resession.get_current()
	if current then
		resession.save(current, { notify = false })
	else
		resession.save_all({ notify = false })
	end
end

--- 新建工作区：保存当前会话 + 开新 tab + 设置根目录
---@param dir? string
function M.new_workspace(dir)
	M.save_session()
	vim.cmd("tabnew")
	if dir then
		M.set_root(dir)
	else
		M.prompt_root()
	end
end

--- 关闭工作区：保存当前会话 + 关闭当前 tab
function M.close_workspace()
	M.save_session()
	if #vim.api.nvim_list_tabpages() > 1 then
		vim.cmd("tabclose")
	end
end

--- 在当前 tab 与上一个 tab 之间切换
function M.alternate()
	if last_tab and vim.api.nvim_tabpage_is_valid(last_tab) and last_tab ~= vim.api.nvim_get_current_tabpage() then
		vim.api.nvim_set_current_tabpage(last_tab)
	end
end

---@param opts? TabWorkspaceConfig
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- 初始化：把当前已列出的 buffer 归到当前 tab
	local cur_tab = vim.api.nvim_get_current_tabpage()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[bufnr].buflisted then
			claim(cur_tab, bufnr)
		end
	end

	local group = vim.api.nvim_create_augroup(GROUP, { clear = true })
	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
		group = group,
		callback = function(args)
			if resession_loading() then
				return
			end
			claim(vim.api.nvim_get_current_tabpage(), args.buf)
			if is_workspace_buf(args.buf) then
				vim.bo[args.buf].buflisted = true
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		callback = function(args)
			if toggling then
				return
			end
			forget(args.buf)
		end,
	})
	vim.api.nvim_create_autocmd("TabLeave", {
		group = group,
		callback = function()
			if not resession_loading() then
				last_tab = vim.api.nvim_get_current_tabpage()
			end
		end,
	})
	vim.api.nvim_create_autocmd("TabEnter", {
		group = group,
		callback = function()
			if resession_loading() then
				return
			end
			M.relist()
			local tab = vim.api.nvim_get_current_tabpage()
			-- TabEnter 时新 tab 的窗口还没切到新 buffer，延迟到切换完成后再同步 LSP
			vim.schedule(function()
				sync_lsp(tab)
			end)
		end,
	})
	vim.api.nvim_create_autocmd("TabClosed", {
		group = group,
		callback = function()
			vim.schedule(prune_closed_tabs)
		end,
	})

	local ok, resession = pcall(require, "resession")
	if ok then
		-- 优先用会话里保存的归属（resession.extensions.tab_workspace）；旧会话没有时才从窗口布局重建
		resession.add_hook("post_load", function()
			vim.schedule(function()
				if imported then
					imported = false
					M.relist()
				else
					M.rebuild()
				end
			end)
		end)

		if M.config.autoload_last_session then
			vim.api.nvim_create_autocmd("VimEnter", {
				group = group,
				once = true,
				callback = function()
					if #vim.fn.argv() > 0 or #vim.api.nvim_list_tabpages() > 1 then
						return
					end
					if vim.tbl_contains(resession.list() or {}, AUTOSAVE_SESSION) then
						resession.load(AUTOSAVE_SESSION, { notify = false })
					end
				end,
			})
			vim.api.nvim_create_autocmd("VimLeavePre", {
				group = group,
				callback = function()
					resession.save(AUTOSAVE_SESSION, { notify = false })
				end,
			})
		end
	end
end

return M
