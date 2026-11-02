-- 每 tab 的 LSP 生命周期：离开 tab 后延迟停掉只属于其它 tab 的 client，进入时按需恢复。
--
-- 恢复依赖 client 自己的 config（client.config: name / cmd / filetypes / root_markers /
-- settings …）。不能用名字去查 vim.lsp.config[name]：只有 lsp/*.lua 声明过的 server
-- 才有那份全局配置，靠 FileType autocmd 内联启动的 client（本仓库里就有）
-- 一旦停掉就再也起不来了。
local util = require("feat.tab_workspace.util")
local state = require("feat.tab_workspace.state")

local M = {}

---@class TabWorkspaceLspConfig
---@field lsp_stop_on_leave boolean
---@field lsp_restart_on_enter boolean
---@field lsp_stop_delay integer

---@type TabWorkspaceLspConfig
local config = {
	lsp_stop_on_leave = true,
	lsp_restart_on_enter = true,
	lsp_stop_delay = 5000,
}

--- 被停掉、等待重新进入 tab 时恢复的 client：
--- 唯一键 -> client.config（同一 server 在不同项目下 root_dir 不同，各自一条）
---@type table<string, table>
local suspended = {}

--- 延迟停止 LSP 的定时器（切 tab 时重置）
---@type uv_timer_t|nil
local stop_timer

---@param cfg? table
function M.configure(cfg)
	if type(cfg) == "table" then
		config = cfg
	end
end

---@param cfg table
---@return string
local function suspend_key(cfg)
	return (cfg.name or "?") .. "\0" .. tostring(cfg.root_dir or "")
end

--- 该 server 在这个 buffer 所在项目里是否启用。
--- lsp_ext.servers 支持「按项目启停」，优先用它；否则退回全局判断。
---@param name string
---@param bufnr integer
---@return boolean
local function is_enabled(name, bufnr)
	local ok, servers = pcall(require, "lsp_ext.servers")
	if ok and type(servers.is_enabled) == "function" then
		local okk, enabled = pcall(servers.is_enabled, name, bufnr)
		if okk and enabled ~= nil then
			return enabled ~= false
		end
	end
	local okk, enabled = pcall(vim.lsp.is_enabled, name)
	return okk and enabled == true
end

--- 该 client 配置是否应该作用在这个 buffer 上
---@param cfg table
---@param bufnr integer
---@return boolean
local function ft_matches(cfg, bufnr)
	local filetypes = cfg.filetypes
	if type(filetypes) ~= "table" or #filetypes == 0 then
		return false
	end
	return vim.tbl_contains(filetypes, vim.bo[bufnr].filetype)
end

--- tab 里参与 LSP 的 buffer
---@param tab integer
---@return integer[]
local function lsp_buffers(tab)
	local out = {}
	for _, bufnr in ipairs(state.tab_buffers(tab)) do
		if util.is_managed_buf(bufnr) then
			out[#out + 1] = bufnr
		end
	end
	return out
end

--- 为 tab 中的 buffer 恢复先前被停掉的服务
---@param bufs integer[]
local function resume(bufs)
	if not config.lsp_restart_on_enter then
		return
	end
	for name, cfg in pairs(suspended) do
		local resumed = false
		for _, bufnr in ipairs(bufs) do
			if
				vim.api.nvim_buf_is_valid(bufnr)
				and ft_matches(cfg, bufnr)
				and is_enabled(cfg.name, bufnr)
				and #vim.lsp.get_clients({ bufnr = bufnr, name = cfg.name }) == 0
			then
				-- 必须带 _root_markers，否则 root_dir 为 nil，Neovim 无法与
				-- vim.lsp.enable 启动的同类 client 复用，会在同一 buffer 起两个。
				local ok = pcall(vim.lsp.start, cfg, { bufnr = bufnr, _root_markers = cfg.root_markers })
				resumed = resumed or ok
			end
		end
		if resumed then
			suspended[name] = nil
		end
	end
end

--- 停掉「当前 tab 不再使用」的 client，并记住它们的启动配置以便切回来时恢复。
---@param tab integer
---@param bufs integer[]
local function sweep(tab, bufs)
	local in_tab = {}
	for _, bufnr in ipairs(bufs) do
		in_tab[bufnr] = true
	end
	for _, client in ipairs(vim.lsp.get_clients()) do
		local used = false
		for bufnr in pairs(client.attached_buffers or {}) do
			if in_tab[bufnr] then
				used = true
				break
			end
		end
		if not used and type(client.config) == "table" then
			-- 没挂 buffer 的 client 也要处理；config 不是 table 的（异常情况）不停，
			-- 停了也恢复不了
			suspended[suspend_key(client.config)] = client.config
			pcall(client.stop, client, true)
		end
	end
end

--- 立即同步：恢复本 tab 需要的 client，停掉不再需要的。
---@param tab integer
function M.sync_now(tab)
	if not vim.api.nvim_tabpage_is_valid(tab) then
		return
	end
	local bufs = lsp_buffers(tab)

	if config.lsp_restart_on_enter then
		-- lsp_ext 的「按项目启停」落到的其实是全局 vim.lsp.enable：在 B 项目关掉
		-- 某个 server 会连 A 项目一起停掉，而切回 A 不会触发 FileType。
		-- 进入 tab 时按本 tab buffer 的项目状态重新应用一遍，再恢复被延迟停掉的 client。
		local ok, servers = pcall(require, "lsp_ext.servers")
		if ok and servers.apply_for_buffer then
			for _, bufnr in ipairs(bufs) do
				pcall(servers.apply_for_buffer, bufnr)
			end
		end
		resume(bufs)
	end

	if config.lsp_stop_on_leave then
		sweep(tab, bufs)
	end
end

--- 切 tab 后同步：恢复立即做，停止延迟做（给「快速切走看一眼再切回来」留缓冲）。
---@param tab integer
function M.sync(tab)
	if not vim.api.nvim_tabpage_is_valid(tab) then
		return
	end
	if stop_timer then
		stop_timer:stop()
		stop_timer:close()
		stop_timer = nil
	end

	local bufs = lsp_buffers(tab)

	if config.lsp_restart_on_enter then
		local ok, servers = pcall(require, "lsp_ext.servers")
		if ok and servers.apply_for_buffer then
			for _, bufnr in ipairs(bufs) do
				pcall(servers.apply_for_buffer, bufnr)
			end
		end
		resume(bufs)
	end

	if not config.lsp_stop_on_leave then
		return
	end

	local delay = tonumber(config.lsp_stop_delay) or 0
	stop_timer = vim.defer_fn(function()
		stop_timer = nil
		if not vim.api.nvim_tabpage_is_valid(tab) or vim.api.nvim_get_current_tabpage() ~= tab then
			return
		end
		sweep(tab, lsp_buffers(tab))
	end, delay)
end

--- 关掉一个 tab 之后调用：TabClosed 事件带不出 tab 句柄，但「当前 tab 不再使用」
--- 的 client 就是被关工作区的，立即停掉，不必等延迟。
function M.on_tab_closed()
	if not config.lsp_stop_on_leave then
		return
	end
	local tab = vim.api.nvim_get_current_tabpage()
	vim.schedule(function()
		if not vim.api.nvim_tabpage_is_valid(tab) then
			return
		end
		sweep(tab, lsp_buffers(tab))
	end)
end

return M
