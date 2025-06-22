local json_store = require("utils.json_store")

local M = {}

-- 创建 JSON 存储实例
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
	default_data = {},
})

-- 需要禁用 LSP 的文件类型列表
local DISABLED_FILETYPES = {
	"gitcommit",
	"markdown",
	"help",
	"qf",
	"makefile",
}

-- 获取当前项目标识（与芯片配置一致）
local function get_current_project_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 读取项目状态缓存（使用 json_store 的 load 方法）
local function load_project_states()
	return state_store:load()
end

-- 保存项目状态到缓存文件（使用 json_store 的 save 方法）
local function save_project_states(states)
	return state_store:save(states)
end

-- 检查当前文件类型是否需要禁用 LSP
local function should_disable_by_filetype()
	local ft = vim.bo.filetype
	for _, disabled_ft in ipairs(DISABLED_FILETYPES) do
		if ft == disabled_ft then
			return true
		end
	end
	return false
end

-- 获取当前项目的 LSP 状态
function M.get_lsp_state()
	-- 如果文件类型在禁用列表中，直接返回 false
	if should_disable_by_filetype() then
		return false
	end

	local project_name = get_current_project_name()
	local states = load_project_states()

	-- 如果项目状态未设置，返回默认值（true）
	if states[project_name] == nil then
		return true
	end

	return states[project_name]
end

-- 设置当前项目的 LSP 状态
function M.set_lsp_state(enabled)
	-- 文件类型禁用时不允许手动启用
	if should_disable_by_filetype() then
		vim.notify("LSP cannot be enabled for this file type", vim.log.levels.WARN)
		return
	end

	local project_name = get_current_project_name()
	local states = load_project_states()
	states[project_name] = enabled
	save_project_states(states)

	-- 更新全局状态
	vim.g.lsp_enabled = enabled
	vim.notify("LSP " .. (enabled and "enabled" or "disabled") .. " for project: " .. project_name)
end

-- 初始化 LSP 状态
function M.init()
	-- 根据文件类型或项目状态设置 LSP
	vim.g.lsp_enabled = M.get_lsp_state()

	-- 设置文件类型变化的自动命令
	vim.api.nvim_create_autocmd("FileType", {
		pattern = table.concat(DISABLED_FILETYPES, ","),
		callback = function()
			-- 当切换到禁用文件类型时自动关闭 LSP
			if vim.g.lsp_enabled then
				vim.g.lsp_enabled = false
				vim.notify("LSP disabled for filetype: " .. vim.bo.filetype, vim.log.levels.INFO)
			end
		end,
	})

	-- 当离开禁用文件类型时恢复项目状态
	vim.api.nvim_create_autocmd("BufLeave", {
		pattern = table.concat(DISABLED_FILETYPES, ","),
		callback = function()
			if not should_disable_by_filetype() then
				local project_name = get_current_project_name()
				local states = load_project_states()
				vim.g.lsp_enabled = states[project_name] ~= false
			end
		end,
	})
end

-- 获取当前禁用的文件类型列表（可选，用于调试或状态显示）
function M.get_disabled_filetypes()
	return DISABLED_FILETYPES
end

return M
