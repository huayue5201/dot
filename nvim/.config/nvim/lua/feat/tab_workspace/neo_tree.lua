-- neo-tree 的多根源：把当前 tab 的主根 + 辅助根并列成一个树。
--
-- 为什么是"源"而不是改 filesystem：filesystem 的树按定义只有一个根
-- （`state.path`），硬塞第二个根要改它的扫描/刷新/搜索路径，等于 fork。
-- 这里只做一层很薄的壳：
--   * 顶层节点 = 工作区自己的根列表（主根 + 辅助根），来自 roots.lua；
--   * 展开某个根 = 直接调 neo-tree 自带的 `fs_scan.get_items(state, 目录, ...)`，
--     过滤/隐藏/嵌套/gitignore/文件监听全部和 filesystem 源完全一致；
--   * 目录节点 id 就是真实路径，打开/重命名/删除/grug-far 等命令照旧可用。
--
-- 单根语义下没有意义的东西（navigate_up、set_root）在 commands 里被关掉：
-- 根由工作区管理（<leader>lw+ / <leader>lw-），不在这里改。
local manager = require("neo-tree.sources.manager")
local renderer = require("neo-tree.ui.renderer")
local fs = require("neo-tree.sources.filesystem")
local fs_scan = require("neo-tree.sources.filesystem.lib.fs_scan")
local fs_commands = require("neo-tree.sources.filesystem.commands")
local utils = require("neo-tree.utils")
local roots = require("feat.tab_workspace.roots")

local M = {
	name = "workspace",
	display_name = " 󰉋 工作区 ",
}

-- 合成根：只为让 hide_root_node 有机会把"N 个根"提升到顶层
local SYNTH_ID = "workspace://roots"

--- 主根 / 辅助根的标记
---@param _ table
---@param node NuiTree.Node
local function workspace_badge(_, node)
	local kind = node.extra and node.extra.workspace_root
	if kind == "primary" then
		return { { text = "主 ", highlight = "NeoTreeWorkspacePrimary" } }
	elseif kind == "aux" then
		return { { text = "辅 ", highlight = "NeoTreeWorkspaceAux" } }
	end
	return {}
end

M.components = vim.tbl_extend("force", {}, require("neo-tree.sources.filesystem.components"), {
	workspace_badge = workspace_badge,
})

-- 命令：整体复用 filesystem 的（open/rename/delete/grug-far 都按真实路径工作），
-- 只替换跟"单根"绑定的几个。
M.commands = vim.tbl_extend("force", {}, fs_commands)
M.commands.refresh = function(state)
	M.navigate(state, state.path, nil, nil, false)
end
M.commands.navigate_up = function() end
M.commands.set_root = function() end

-- 展开目录：走 filesystem 自己的实现（它只依赖 state，不依赖源名）
M.toggle_directory = fs.toggle_directory

--- 当前 tab 的根节点列表
---@param state neotree.State
---@return table[]
local function root_items(state)
	local tab = state.tabid or vim.api.nvim_get_current_tabpage()
	local items = {}
	for i, dir in ipairs(roots.all(tab)) do
		items[i] = {
			id = dir,
			name = vim.fn.fnamemodify(dir, ":~"),
			type = "directory",
			loaded = false,
			extra = { workspace_root = i == 1 and "primary" or "aux" },
		}
	end
	return items
end

---@param state neotree.State
---@param path_to_reveal? string
local function reveal_root(state, path_to_reveal)
	if not path_to_reveal then
		return
	end
	local tab = state.tabid or vim.api.nvim_get_current_tabpage()
	local dir = roots.find_root(tab, path_to_reveal)
	if not dir then
		return
	end
	-- 先渲染根列表，再让 filesystem 的扫描把祖先目录展开到目标文件
	vim.schedule(function()
		pcall(fs_scan.get_items, state, dir, vim.fn.fnamemodify(path_to_reveal, ":p"), nil, false)
	end)
end

---@param state neotree.State
---@param path string?
---@param path_to_reveal string?
---@param callback function?
---@param async boolean?
function M.navigate(state, _path, path_to_reveal, callback, _async)
	state._ready = false
	-- fs_scan 只认一个 state.path（gitignore 标记、refresh 都基于它）：主根。
	state.path = roots.primary(state.tabid or vim.api.nvim_get_current_tabpage())
	local items = root_items(state)
	if #items == 0 then
		renderer.show_nodes({}, state, nil, callback)
		return
	end
	local tree_root = {
		id = SYNTH_ID,
		name = "工作区",
		type = "directory",
		loaded = true,
		children = items,
	}
	renderer.show_nodes({ tree_root }, state, nil, function()
		reveal_root(state, path_to_reveal)
		if type(callback) == "function" then
			callback()
		end
	end)
end

---@param config table
---@param global_config table
function M.setup(config, global_config)
	-- neo-tree 只把「源自己那一段」配置交给源，filesystem 的默认值（filtered_items、
	-- hijack_netrw、group_empty_dirs...）不会自动继承过来，这里显式拿过来做底。
	if not config._defaults_merged then
		local base = vim.deepcopy(require("neo-tree.defaults").filesystem)
		local merged = vim.tbl_deep_extend("force", base, config)
		for key in pairs(config) do
			config[key] = nil
		end
		for key, value in pairs(merged) do
			config[key] = value
		end
		config._defaults_merged = true
	end

	config.bind_to_cwd = config.bind_to_cwd == true and true or false
	config.hijack_netrw_behavior = "disabled"
	if config.enable_git_status == nil then
		config.enable_git_status = global_config.enable_git_status
	end

	-- 与 filesystem 源一致的过滤规则归一化（glob → lua pattern，名单 → set）
	if not config._normalized then
		local glob = require("neo-tree.sources.filesystem.lib.globtopattern")
		local filtered = config.filtered_items
		for _, list in ipairs({
			filtered.hide_by_pattern or {},
			filtered.always_show_by_pattern or {},
			filtered.never_show_by_pattern or {},
		}) do
			for i, pattern in ipairs(list) do
				list[i] = glob.globtopattern(pattern)
			end
		end
		for _, key in ipairs({ "hide_by_name", "always_show", "never_show" }) do
			if type(filtered[key]) == "table" then
				filtered[key] = utils.list_to_dict(filtered[key])
			end
		end
		config._normalized = true
	end

	vim.api.nvim_set_hl(0, "NeoTreeWorkspacePrimary", { link = "DiagnosticOk", default = true })
	vim.api.nvim_set_hl(0, "NeoTreeWorkspaceAux", { link = "DiagnosticInfo", default = true })

	local aug = vim.api.nvim_create_augroup("NeoTreeWorkspace", { clear = true })
	local refresh = function()
		pcall(manager.refresh, "workspace")
	end
	vim.api.nvim_create_autocmd("User", { group = aug, pattern = "TabWorkspaceRoots", callback = refresh })
	vim.api.nvim_create_autocmd("User", { group = aug, pattern = "TabWorkspaceRoot", callback = refresh })
end

return M
