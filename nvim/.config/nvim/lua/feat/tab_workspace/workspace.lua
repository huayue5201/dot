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
		vim.notify(string.format("工作区根目录不存在: %s", dir), vim.log.levels.WARN)
		return false
	end
	-- 用表形式传参：目录里带空格/特殊字符也不需要手动 fnameescape
	local ok, err = pcall(vim.cmd.tcd, { args = { dir } })
	if not ok then
		vim.notify(string.format("切换工作区根目录失败: %s", tostring(err)), vim.log.levels.ERROR)
	else
		-- 显式设根 = 锁定：自动跟随不再覆盖它（<leader>lwR 解除）
		require("feat.tab_workspace.root").set_pin(vim.api.nvim_get_current_tabpage(), dir)
	end
	return ok
end

--- 交互式设置当前 tab 根目录
---@param on_done? fun(ok: boolean)
function M.prompt_root(on_done)
	vim.ui.input({ prompt = "工作区根目录: ", default = vim.fn.getcwd(), completion = "dir" }, function(input)
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
				string.format("会话 %s 属于其它项目，当前工作区未保存（未覆盖）", current),
				vim.log.levels.WARN
			)
			return
		end
	end
	-- save_all 会带上 session_configs 里记录的 dir（自定义会话目录也不会写错地方）
	resession.save_all({ notify = false })
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
	local ok_guard, guard = pcall(require, "feat.tab_workspace.session_guard")
	if not name then
		local sessions = resession.list({ dir = opts.dir })
		if vim.tbl_isempty(sessions) then
			vim.notify("没有已保存的会话", vim.log.levels.WARN)
			return
		end
		local ok_util, util = pcall(require, "resession.util")
		local items = {}
		for _, session_name in ipairs(sessions) do
			local data = ok_guard and guard.read(session_name, opts) or nil
			local path = ok_util and util.get_session_file(session_name, opts.dir) or nil
			items[#items + 1] = {
				name = session_name,
				data = data,
				mtime = path and vim.fn.getftime(path) or 0,
			}
		end
		-- 与 load_order = "modification_time" 一致：最近的在前
		table.sort(items, function(a, b)
			return a.mtime > b.mtime
		end)
		vim.ui.select(items, {
			prompt = "载入会话",
			format_item = function(item)
				local data = item.data
				if type(data) ~= "table" then
					return item.name
				end
				local dir = data.tab_scoped and data.tabs and data.tabs[1] and data.tabs[1].cwd
					or data.global and data.global.cwd
				local tag = data.tab_scoped and "(tab) " or ""
				if type(dir) == "string" and dir ~= "" then
					return string.format("%s%s [%s]", tag, item.name, vim.fn.fnamemodify(dir, ":~"))
				end
				return tag .. item.name
			end,
		}, function(selected)
			if selected then
				M.load_session(selected.name, opts)
			end
		end)
		return
	end
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
		vim.ui.input(
			{ prompt = "新工作区根目录: ", default = vim.fn.getcwd(), completion = "dir" },
			function(input)
				if input and input ~= "" then
					M.new_workspace(input)
				end
			end
		)
		return
	end
	-- 先校验再建 tab：目录不对时不要留下一个没有根目录的空 tab
	local root = vim.fn.fnamemodify(vim.fn.expand(dir), ":p")
	if vim.fn.isdirectory(root) == 0 then
		vim.notify(string.format("工作区根目录不存在: %s", root), vim.log.levels.WARN)
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

return M
