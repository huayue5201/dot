-- lua/lsp-config/servers.lua
---@brief LSP server 生命周期：按项目状态启停 / 交互切换 / 重启
local M = {}

local registry = require("lsp-config.registry")
local state = require("lsp-config.state")

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

---启用/停用某个 server，并记录到当前项目
---@param name string
---@param enabled boolean
---@param bufnr integer|nil
function M.set_enabled(name, enabled, bufnr)
	state.set("lsp." .. name, enabled, bufnr)
	if vim.lsp.is_enabled(name) ~= enabled then
		vim.lsp.enable(name, enabled)
	end
end

---重启某个 server（先停其客户端，再重新启用）
---@param name string
---@param bufnr integer|nil
function M.restart_server(name, bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = name })) do
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
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		client:stop(true)
	end

	vim.defer_fn(function()
		vim.lsp.enable(registry.get_lsp_name(), true)
	end, 500)
end

return M
