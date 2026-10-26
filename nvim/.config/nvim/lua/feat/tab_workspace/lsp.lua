-- 每 tab 的 LSP 生命周期：离开 tab 后延迟停止只属于它的 client，进入时按需恢复。
local M = {}

local ownership = require("feat.tab_workspace.ownership")

---@type table
local config = {
	lsp_stop_on_leave = true,
	lsp_restart_on_enter = true,
	lsp_stop_delay = 50000,
}

--- 被本模块停掉、等待重新进入 tab 时恢复的 LSP 服务名
local suspended = {}

-- 延迟停止 LSP 的定时器（切 tab 时重置）
local stop_timer

---@param cfg table
function M.configure(cfg)
	config = cfg or config
end

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
			for _, bufnr in ipairs(ownership.tab_buffers(tab)) do
				if
					vim.api.nvim_buf_is_valid(bufnr)
					and vim.bo[bufnr].buftype == ""
					and #vim.lsp.get_clients({ bufnr = bufnr, name = name }) == 0
					and (not cfg.filetypes or vim.tbl_contains(cfg.filetypes, vim.bo[bufnr].filetype))
				then
					-- 必须带 _root_markers，否则 root_dir 为 nil，Neovim 无法与
					-- vim.lsp.enable 启动的同类 client 复用，会在同一 buffer 起两个。
					if pcall(vim.lsp.start, cfg, { bufnr = bufnr, _root_markers = cfg.root_markers }) then
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

--- 切走后延迟停掉「当前 tab 不再使用」的 client。
--- 快速来回切 tab 时 TabEnter 会取消该定时器，避免刚停就重启。
---@param tab integer
local function schedule_lsp_stop(tab)
	if stop_timer then
		stop_timer:stop()
		stop_timer:close()
		stop_timer = nil
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
		local current = {}
		for _, bufnr in ipairs(ownership.tab_buffers(tab)) do
			current[bufnr] = true
		end
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
	end, delay)
end

--- 切换 tab 后同步 LSP：立即恢复本 tab 需要的 client，
--- 并延迟停止不再需要的（给「快速切走看一眼再切回来」留时间）。
---@param tab integer
function M.sync(tab)
	if not vim.api.nvim_tabpage_is_valid(tab) then
		return
	end
	if config.lsp_restart_on_enter then
		-- lsp_ext 的「按项目启停」实际是全局 vim.lsp.enable：在 B 项目关掉
		-- 某个 server 会连 A 项目一起停掉，而切回 A 不会触发 FileType。
		-- 进入 tab 时按本 tab buffer 的项目状态重新应用一遍，再恢复被延迟停掉的 client。
		local ok, servers = pcall(require, "lsp_ext.servers")
		if ok and servers.apply_for_buffer then
			for _, bufnr in ipairs(ownership.tab_buffers(tab)) do
				if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
					pcall(servers.apply_for_buffer, bufnr)
				end
			end
		end
		resume_tab_clients(tab)
	end
	schedule_lsp_stop(tab)
end

return M
