-- utils/project_lsp_toggle.lua
local M = {}
local PathStore = require("utils.json_store")
local lsp_utils = require("lsp.lsp_utils")

-- 初始化存储
local state_file = vim.fn.stdpath("data") .. "/project_lsp_state.json"
local store = PathStore:new({
	file_path = state_file,
	default_data = {},
	auto_save = true,
})

-- 获取当前项目 root
local function get_project_root()
	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
	if git_root and git_root ~= "" then
		return git_root
	end
	return vim.fn.getcwd()
end

-- 设置项目 LSP 状态
-- enabled = true / false
function M.set_lsp_state(enabled)
	local root = get_project_root()
	store:set(root, enabled)

	-- 根据状态立即启停当前缓冲区 LSP
	if enabled then
		lsp_utils.restart_lsp()
	else
		lsp_utils.stop_lsp()
	end
end

-- 获取项目 LSP 状态
-- 返回 true = 启用，false = 禁用
function M.get_lsp_state()
	local root = get_project_root()
	local v = store:get(root)
	return v ~= false -- 默认启用
end

-- 在 Neovim 启动 / buffer 打开时自动恢复状态
function M.apply_project_state(bufnr)
	bufnr = bufnr or 0
	local state = M.get_lsp_state()
	if state == false then
		lsp_utils.stop_lsp()
	else
		-- 可选：只在 LSP 未 attach 时重启
		local clients = lsp_utils.get_active_lsps(bufnr)
		if #clients == 0 then
			lsp_utils.restart_lsp()
		end
	end
end

-- 命令绑定（可选）
vim.api.nvim_create_user_command("ProjectLspEnable", function()
	M.set_lsp_state(true)
	vim.notify("✅ 项目 LSP 已启用", vim.log.levels.INFO)
end, {})

vim.api.nvim_create_user_command("ProjectLspDisable", function()
	M.set_lsp_state(false)
	vim.notify("⛔ 项目 LSP 已禁用", vim.log.levels.WARN)
end, {})

vim.api.nvim_create_user_command("ProjectLspToggle", function()
	local state = M.get_lsp_state()
	M.set_lsp_state(not state)
	vim.notify("🔄 项目 LSP 状态切换为 " .. (not state and "禁用" or "启用"), vim.log.levels.INFO)
end, {})

return M
