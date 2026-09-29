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

---交互式切换当前文件类型的某个 server（项目级持久化）
function M.toggle()
	local lsp_names = registry.get_lsp_by_filetype(vim.bo.filetype)

	vim.ui.select(lsp_names, {
		prompt = "选择 LSP 客户端：",
		format_item = function(item)
			local enabled = state.get("lsp." .. item, nil, true)
			return string.format("%-20s • 状态: %s", item, enabled and "active" or "inactive")
		end,
	}, function(selected)
		if not selected then
			return
		end

		local key = "lsp." .. selected
		local next_enabled = not state.get(key, nil, true)

		vim.lsp.enable(selected, next_enabled)
		state.set(key, next_enabled)

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
