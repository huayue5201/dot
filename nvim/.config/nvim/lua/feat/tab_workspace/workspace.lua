-- 工作区动作：切根目录、新建/关闭/切换工作区、保存会话。
local lifecycle = require("feat.tab_workspace.lifecycle")
local state = require("feat.tab_workspace.state")

local M = {}

--- 设置当前 tab 的工作区根目录（按 tab 用 :tcd，neo-tree 会经 DirChanged 自动跟随）
---@param dir? string
---@return boolean ok
function M.set_root(dir)
	if not dir or dir == "" then
		dir = vim.fn.getcwd()
	end
	dir = vim.fn.fnamemodify(vim.fn.expand(dir), ":p")
	-- 末尾的 / 让 :tcd 之后的显示更好看，同时 isdirectory 也接受它
	if vim.fn.isdirectory(dir) == 0 then
		vim.notify(string.format("workspace root does not exist: %s", dir), vim.log.levels.WARN)
		return false
	end
	-- 用表形式传参：目录里带空格/特殊字符也不需要手动 fnameescape
	local ok, err = pcall(vim.cmd.tcd, { args = { dir } })
	if not ok then
		vim.notify(string.format("failed to switch workspace root: %s", tostring(err)), vim.log.levels.ERROR)
	else
		-- 显式设根 = 锁定：自动跟随不再覆盖它（<leader>lwR 解除）
		require("feat.tab_workspace.root").set_pin(vim.api.nvim_get_current_tabpage(), dir)
	end
	return ok
end

--- 交互式设置当前 tab 根目录
---@param on_done? fun(ok: boolean)
function M.prompt_root(on_done)
	vim.ui.input({ prompt = "Workspace root: ", default = vim.fn.getcwd(), completion = "dir" }, function(input)
		if not input or input == "" then
			return
		end
		local ok = M.set_root(input)
		if on_done then
			on_done(ok)
		end
	end)
end

--- 保存当前会话（若有）
--- 覆盖前先确认当前工作区确实属于该会话：resession 的 current_session 只记住
--- 「上次 load 的名字」，载入 A 后在 B 里干活会把 B 写进 A.json（存 A 打开成 B）。
function M.save_session()
	local ok, resession = pcall(require, "resession")
	if not ok then
		return
	end
	local current = resession.get_current()
	if current then
		local ok_guard, guard = pcall(require, "feat.tab_workspace.session_guard")
		if ok_guard and not guard.fits(current) then
			vim.notify(
				string.format(
					"session %s belongs to another project; current workspace not saved (kept intact)",
					current
				),
				vim.log.levels.WARN
			)
			return
		end
	end
	-- save_all 会带上 session_configs 里记录的 dir（自定义会话目录也不会写错地方）
	resession.save_all({ notify = false })
end

--- 工作区 / 会话统一选择器
---
--- 列表 = 已打开的 tab（工作区） + 已保存但未打开的会话 + 「打开新目录」。
--- 选择已打开的 tab → 切过去；选择会话 → 新开 tab 里载入（不顶掉当前工作区）；
--- 选择「打开新目录」→ 走 new_workspace（会先保存当前会话）。
---@param opts? table
function M.picker(opts)
	opts = opts or {}
	local root = require("feat.tab_workspace.root")
	local ok_state, state = pcall(require, "feat.tab_workspace.state")
	local ok_guard, guard = pcall(require, "feat.tab_workspace.session_guard")
	local current_tab = vim.api.nvim_get_current_tabpage()

	local items = {}
	local open_roots = {}

	-- 1. 已打开的工作区（按 tab 顺序）
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local dir = root.cwd(tab)
		open_roots[(dir:gsub("/+$", ""))] = true
		items[#items + 1] = {
			kind = "tab",
			tab = tab,
			number = vim.api.nvim_tabpage_get_number(tab),
			label = root.name(tab),
			dir = vim.fn.fnamemodify(dir, ":~"),
			buffers = ok_state and #state.tab_buffers(tab) or 0,
			current = tab == current_tab,
		}
	end

	-- 2. 已保存、但根目录还没被任何 tab 打开的会话（最近的在前）
	local ok_resession, resession = pcall(require, "resession")
	if ok_resession then
		local ok_list, sessions = pcall(resession.list, { dir = opts.dir })
		local ok_util, util = pcall(require, "resession.util")
		local saved = {}
		for _, name in ipairs(type(sessions) == "table" and sessions or {}) do
			local data = ok_guard and guard.read(name, opts) or nil
			local opened = false
			if ok_guard and type(data) == "table" then
				for path in pairs(guard.roots_of_data(data)) do
					if open_roots[path] then
						opened = true
						break
					end
				end
			end
			if not opened then
				local dir
				if type(data) == "table" then
					local first_tab = data.tabs and data.tabs[1]
					dir = type(first_tab) == "table" and first_tab.cwd or data.global and data.global.cwd
				end
				-- 与 load_order = "modification_time" 一致：最近的在前
				local path = ok_util and util.get_session_file(name, opts.dir)
				saved[#saved + 1] = {
					kind = "session",
					name = name,
					dir = type(dir) == "string" and dir ~= "" and vim.fn.fnamemodify(dir, ":~") or "",
					mtime = path and vim.fn.getftime(path) or 0,
				}
			end
		end
		table.sort(saved, function(a, b)
			return a.mtime > b.mtime
		end)
		vim.list_extend(items, saved)
	end

	items[#items + 1] = { kind = "new" }

	---@param item table
	---@return string
	local function format_item(item)
		if item.kind == "new" then
			return "+ Open directory…"
		end
		if item.kind == "tab" then
			return string.format(
				"%s %d  %s  %s  %d buf",
				item.current and "●" or "○",
				item.number,
				item.label,
				item.dir,
				item.buffers
			)
		end
		return string.format("·    %s  %s", item.name, item.dir)
	end

	vim.ui.select(items, {
		prompt = "Workspace",
		format_item = format_item,
	}, function(item)
		if not item then
			return
		end
		if item.kind == "tab" then
			if vim.api.nvim_tabpage_is_valid(item.tab) then
				vim.api.nvim_set_current_tabpage(item.tab)
			end
		elseif item.kind == "session" then
			-- 新开一个 tab 再载入：tab 作用域会话会复用「干净的当前 tab」，
			-- 直接载入会把当前工作区顶掉。
			M.save_session()
			vim.cmd("tabnew")
			M.load_session(item.name, opts)
		else
			M.new_workspace()
		end
	end)
end

--- 载入会话（tab 作用域会话会复用当前 tab，而不是每载一次多一个 tab）
---@param name? string
---@param opts? table
function M.load_session(name, opts)
	local ok, resession = pcall(require, "resession")
	if not ok then
		return
	end
	opts = vim.tbl_extend("keep", opts or {}, { attach = true })
	if not name then
		-- 无参 = 交互选择：统一到 picker（同一个入口管「打开中的 / 已保存的 / 新目录」）
		return M.picker(opts)
	end
	local ok_guard, guard = pcall(require, "feat.tab_workspace.session_guard")
	local data = ok_guard and guard.read(name, opts) or nil
	if type(data) == "table" and data.tab_scoped then
		if ok_guard then
			guard.reuse_current_tab()
		end
	end
	resession.load(name, opts)
end

--- 新建工作区：保存当前会话 + 开新 tab + 设置根目录。
--- 没给目录时先问目录：取消就什么都不做，不要留下一个没有根目录的空 tab。
---@param dir? string
---@return boolean|nil
function M.new_workspace(dir)
	if not dir or dir == "" then
		-- 先问目录再建 tab：取消就什么都不做
		vim.ui.input({ prompt = "New workspace root: ", default = vim.fn.getcwd(), completion = "dir" }, function(input)
			if input and input ~= "" then
				M.new_workspace(input)
			end
		end)
		return
	end
	-- 先校验再建 tab：目录不对时不要留下一个没有根目录的空 tab
	local root = vim.fn.fnamemodify(vim.fn.expand(dir), ":p")
	if vim.fn.isdirectory(root) == 0 then
		vim.notify(string.format("workspace root does not exist: %s", root), vim.log.levels.WARN)
		return false
	end
	M.save_session()
	vim.cmd("tabnew")
	return M.set_root(root)
end

--- 关闭工作区：关 tab → 清理归属与孤儿 buffer → 保存会话。
--- 顺序很重要：先保存会把「刚关掉的 tab」继续留在会话文件里，下次 load 又复活。
function M.close_workspace()
	if #vim.api.nvim_list_tabpages() > 1 then
		vim.cmd("tabclose")
	end
	lifecycle.prune()
	M.save_session()
end

--- 在当前 tab 与上一个 tab 之间切换
function M.alternate()
	local last = state.last_tab()
	if not last or not vim.api.nvim_tabpage_is_valid(last) or last == vim.api.nvim_get_current_tabpage() then
		-- 上一个 tab 已经关掉了：清掉记录，别留一个永远失效的目标
		state.set_last_tab(nil)
		return
	end
	vim.api.nvim_set_current_tabpage(last)
end

-- ================= 辅助根（主根 + N 辅助根）=================

--- 给当前工作区附加一个辅助根（<leader>lw+）
--- cwd 永远是主根；辅助根只影响多根消费者（<leader>ew 的 workspace 树、会话）。
---@param dir? string 省略则交互输入
function M.attach_root(dir)
	local roots = require("feat.tab_workspace.roots")
	local function run(input)
		local ok, err = roots.attach(vim.api.nvim_get_current_tabpage(), input)
		if not ok then
			vim.notify("not attached: " .. tostring(err), vim.log.levels.WARN)
		end
		return ok
	end
	if dir then
		return run(dir)
	end
	vim.ui.input(
		{ prompt = "Attach root directory: ", default = vim.fn.getcwd() .. "/", completion = "dir" },
		function(input)
			if input and input ~= "" then
				run(input)
			end
		end
	)
end

--- 移除辅助根（<leader>lw-）：无参数时在当前辅助根里选
---@param dir? string
function M.detach_root(dir)
	local roots = require("feat.tab_workspace.roots")
	local tab = vim.api.nvim_get_current_tabpage()
	if dir then
		if not roots.detach(tab, dir) then
			vim.notify("not an extra root: " .. dir, vim.log.levels.WARN)
		end
		return
	end
	local list = roots.aux(tab)
	if #list == 0 then
		vim.notify("no extra roots in this workspace", vim.log.levels.INFO)
		return
	end
	vim.ui.select(list, {
		prompt = "Remove extra root: ",
		format_item = function(d)
			return vim.fn.fnamemodify(d, ":~")
		end,
	}, function(choice)
		if choice then
			roots.detach(tab, choice)
		end
	end)
end

--- 当前工作区的根列表（主根在前）
---@return string[]
function M.roots()
	return require("feat.tab_workspace.roots").all(vim.api.nvim_get_current_tabpage())
end

--- 打开多根树（neo-tree 的 workspace 源）
function M.tree()
	vim.cmd("Neotree workspace toggle")
end

return M
