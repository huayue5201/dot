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

-- 获取当前项目标识（使用路径的哈希值）
local function get_current_project_name()
	local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
	local cwd = vim.fn.getcwd()
	-- 使用 sha256 哈希函数
	local hash = vim.fn.sha256(cwd)
	-- 取前8位，足够唯一且较短
	return project_name .. "-" .. hash:sub(1, 8)
end

-- 获取当前项目显示名称（用于通知）
local function get_project_display_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 读取项目状态缓存
local function load_project_states()
	return state_store:load()
end

-- 保存项目状态到缓存文件
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

	local project_id = get_current_project_name()
	local states = load_project_states()

	-- 如果项目状态未设置，返回默认值（true）
	if states[project_id] == nil then
		return true
	end

	return states[project_id]
end

-- 设置当前项目的 LSP 状态
function M.set_lsp_state(enabled)
	-- 文件类型禁用时不允许手动启用
	if should_disable_by_filetype() then
		vim.notify("LSP cannot be enabled for this file type", vim.log.levels.WARN)
		return
	end

	local project_id = get_current_project_name()
	local project_name = get_project_display_name()
	local states = load_project_states()

	-- 检查状态是否实际变化
	if states[project_id] == enabled then
		return
	end

	states[project_id] = enabled
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
				local project_id = get_current_project_name()
				local states = load_project_states()
				vim.g.lsp_enabled = states[project_id] ~= false
			end
		end,
	})
end

-- 获取当前禁用的文件类型列表
function M.get_disabled_filetypes()
	return DISABLED_FILETYPES
end

return M
