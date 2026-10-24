-- lua/lsp_ext/servers.lua
---@brief LSP server 生命周期：按项目状态启停 / 交互切换 / 重启
local M = {}

local registry = require("lsp_ext.registry")
local state = require("lsp_ext.state")

---按 buffer 所属项目的持久化状态，启用/停用其文件类型对应的 server（幂等）
---@param bufnr integer|nil
function M.apply_for_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local lsp_names = registry.get_lsp_by_filetype(vim.bo[bufnr].filetype)

	for _, lsp_name in ipairs(lsp_names) do
		-- 未设置视为启用；只有用户显式改成 false 才禁用
		local should_enable = state.get("lsp." .. lsp_name, bufnr, true) ~= false

		-- 幂等：只有状态不一致时才调用 enable，避免重复触发 doautoall
		if vim.lsp.is_enabled(lsp_name) ~= should_enable then
			vim.lsp.enable(lsp_name, should_enable)
		end
	end
end

---某个 server 在当前项目里是否启用（未设置视为启用）
---@param name string
---@param bufnr integer|nil
---@return boolean
function M.is_enabled(name, bufnr)
	return state.get("lsp." .. name, bufnr, true) ~= false
end

---@param name string
---@param bufnr integer|nil
---@return integer started 实际启动了几个 buffer
function M.reattach(name, bufnr)
	local ok, cfg = pcall(function()
		return vim.lsp.config[name]
	end)
	if not (ok and type(cfg) == "table") then
		return 0
	end
	local started = 0
	local buffers = bufnr and { bufnr } or vim.api.nvim_list_bufs()
	for _, b in ipairs(buffers) do
		if
			vim.api.nvim_buf_is_valid(b)
			and vim.api.nvim_buf_is_loaded(b)
			and vim.bo[b].buftype == ""
			and (not cfg.filetypes or vim.tbl_contains(cfg.filetypes, vim.bo[b].filetype))
			and #vim.lsp.get_clients({ bufnr = b, name = name }) == 0
		then
			if pcall(vim.lsp.start, cfg, { bufnr = b }) then
				started = started + 1
			end
		end
	end
	return started
end

---启用/停用某个 server，并记录到当前项目
---@param name string
---@param enabled boolean
---@param bufnr integer|nil
function M.set_enabled(name, enabled, bufnr)
	state.set("lsp." .. name, enabled, bufnr)
	if vim.lsp.is_enabled(name) ~= enabled then
		vim.lsp.enable(name, enabled)
	end
	-- vim.lsp.enable(true) 内部只做 doautoall(FileType)，而 buf_attach_client 对
	-- 「已经 attach 过的 buffer」直接 return，所以刚被 stop 掉的 client 不会重新贴上，
	-- 结果 clients=0 一直挂到下一次 FileType。re-enable 后必须显式补一次 start。
	if enabled then
		M.reattach(name)
	end
end

---重启某个 server（先停其客户端，再重新启用）
---@param name string
---@param bufnr integer|nil
function M.restart_server(name, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = name })) do
		-- 先 detach（发 didClose）再 kill，否则 server 侧文档还开着，
		-- 新 client 再 didOpen 同一个 URI 时 rust-analyzer 会报
		-- "duplicate DidOpenTextDocument"。
		pcall(vim.lsp.buf_detach_client, bufnr, client.id)
		client:stop(true)
	end
	vim.defer_fn(function()
		M.set_enabled(name, true, bufnr)
	end, 300)
end

---交互式切换当前文件类型的某个 server（项目级持久化）
function M.toggle()
	local lsp_names = registry.get_lsp_by_filetype(vim.bo.filetype)

	vim.ui.select(lsp_names, {
		prompt = "选择 LSP 客户端：",
		format_item = function(item)
			local enabled = M.is_enabled(item)
			return string.format("%-20s • 状态: %s", item, enabled and "active" or "inactive")
		end,
	}, function(selected)
		if not selected then
			return
		end

		M.set_enabled(selected, not M.is_enabled(selected))
		vim.schedule(vim.cmd.redrawstatus)
	end)
end

---重启当前 buffer 的 LSP
function M.restart()
	local bufnr = vim.api.nvim_get_current_buf()
	local names = registry.get_lsp_by_filetype(vim.bo[bufnr].filetype)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		pcall(vim.lsp.buf_detach_client, bufnr, client.id)
		client:stop(true)
	end

	vim.defer_fn(function()
		if not (vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)) then
			return
		end
		for _, name in ipairs(names) do
			vim.lsp.enable(name, true)
			M.reattach(name, bufnr)
		end
	end, 500)
end

return M
