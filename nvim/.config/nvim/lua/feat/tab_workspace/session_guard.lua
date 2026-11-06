-- 会话覆盖保护。
--
-- resession 的 current_session 只记住「上次 load 的名字」，跟目录无关；
-- 载入 A 之后在 B 里干活，autosave（定时器 / VimLeavePre）会走
-- save_all() → save(current_session)，把 B 的 buffer、tab cwd 写回 A.json。
-- 结果就是「明明存的 A，下次打开成了 B」。
--
-- 这里在写入前比对「当前各 tab 的根」和「会话文件里记录的根」：没有交集
-- 就拒绝覆盖（属于别的项目），而不是静默写坏。同一会话里新开一个别的项目的
-- tab 不会被误判——只要还有一个当前 tab 的根与会话里的根重合就允许保存。
local M = {}

---@param path string?
---@return string?
local function norm(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	path = path:gsub("/+$", "")
	local ok, real = pcall(vim.uv.fs_realpath, path)
	return (ok and real) or path
end

--- 会话文件里记录的根目录集合
---@param data table
---@return table<string, true>
function M.roots_of_data(data)
	local roots = {}
	for _, tab in ipairs(data.tabs or {}) do
		if type(tab) == "table" then
			local dir = norm(tab.cwd)
			if dir then
				roots[dir] = true
			end
		end
	end
	-- 只在「会话里没存任何 tab 根」时才退回 global.cwd。
	-- global.cwd 是保存时活动 tab 的目录，可能是 /tmp、$HOME 这类很宽的目录，
	-- 拿它做归属判断会让会话「命中」所有项目。旧会话（全用 :cd 那种）只能靠它。
	if next(roots) == nil and type(data.global) == "table" then
		local dir = norm(data.global.cwd)
		if dir then
			roots[dir] = true
		end
	end
	return roots
end

--- 当前每个 tab 的根目录集合
---@return table<string, true>
function M.current_roots()
	local roots = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		local dir = norm(vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(tab)))
		if dir then
			roots[dir] = true
		end
	end
	return roots
end

--- 读会话文件（走 resession 自己的读入口，已含 terminal 清洗与 cwd 兜底）
---@param name string
---@param opts? table
---@return table?
function M.read(name, opts)
	local ok, resession = pcall(require, "resession")
	if not ok then
		return nil
	end
	local ok_files, files = pcall(require, "resession.files")
	local ok_util, util = pcall(require, "resession.util")
	if not (ok_files and ok_util) then
		return nil
	end
	local ok_path, path = pcall(util.get_session_file, name, (opts or {}).dir)
	if not ok_path then
		return nil
	end
	return files.load_json_file(path)
end

--- 当前工作区是否能覆盖这个会话
---@param name string
---@param opts? table
---@return boolean
function M.fits(name, opts)
	local data = M.read(name, opts)
	if type(data) ~= "table" then
		-- 会话文件不存在/读不出来：按新会话处理，允许写
		return true
	end
	local theirs = M.roots_of_data(data)
	if next(theirs) == nil then
		return true
	end
	local mine = M.current_roots()
	for root in pairs(mine) do
		if theirs[root] then
			return true
		end
	end
	return false
end

--- 载入后把「全局 cwd」归位到当前 tab 的根。
--
-- resession 保存的 global.cwd 其实是「保存时活动 tab 的根」（getcwd(-1, -1)），
-- 载入时却用它 :cd 整个实例；之后 :tabnew 或没有 tab-local 的窗口就会继承
-- 那个上一个项目的目录，表现为「切回来却落在别的项目」。
function M.fix_global_cwd()
	local ok, dir = pcall(vim.fn.getcwd)
	if ok and type(dir) == "string" and dir ~= "" and vim.fn.isdirectory(dir) == 1 then
		pcall(vim.api.nvim_set_current_dir, dir)
	end
end

--- 修会话数据里的失效目录。
--
-- global.cwd / tab.cwd 指向已删除/改名的目录时，resession 的 nvim_set_current_dir
-- 会抛 E344，整次加载中断（只剩一个空 tab）。这里换成有效的目录或清掉 tab.cwd。
---@param data table
---@return table
function M.sanitize_cwd(data)
	if type(data) ~= "table" then
		return data
	end
	local function valid(dir)
		return type(dir) == "string" and dir ~= "" and vim.fn.isdirectory(dir) == 1
	end

	local fallback
	for _, tab in ipairs(data.tabs or {}) do
		if type(tab) == "table" and valid(tab.cwd) then
			fallback = tab.cwd
			break
		end
	end
	fallback = fallback or vim.fn.getcwd()

	for _, tab in ipairs(data.tabs or {}) do
		if type(tab) == "table" and type(tab.cwd) == "string" and not valid(tab.cwd) then
			tab.cwd = nil
		end
	end

	if type(data.global) == "table" then
		if not valid(data.global.cwd) then
			data.global.cwd = fallback
		end
	elseif fallback then
		data.global = { cwd = fallback }
	end
	return data
end

--- tab 作用域会话载入前：把当前 tab 变成 resession 眼中的「干净 tab」。
--
-- resession 对 tab 作用域会话走 open_clean_tab()：当前 tab 不是
-- 「单窗口 + 无名空 buffer」就 :tabnew，于是每载一次多一个 tab。
-- 这里先 only + :enew!，让 load 复用当前 tab；原有 buffer 仍留在 buffer 列表里，
-- 不删除、不丢改动（只是不再显示）。
function M.reuse_current_tab()
	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		pcall(vim.cmd.only, { mods = { emsg_silent = true } })
	end
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local is_clean = vim.api.nvim_buf_get_name(buf) == ""
		and vim.bo[buf].buftype == ""
		and #lines == 1
		and lines[1] == ""
	if is_clean then
		return
	end
	pcall(vim.cmd.enew, { bang = true })
end

--- 带保护的自动保存（替代 resession 自带的 autosave）
---@param opts? table
function M.autosave(opts)
	local ok, resession = pcall(require, "resession")
	if not ok then
		return
	end
	local current = resession.get_current()
	if current and not M.fits(current) then
		return
	end
	resession.save_all(opts)
end

--- 注册带保护的 autosave：定时器 + 退出时各一次
---@param opts? { interval?: integer, notify?: boolean }
function M.setup_autosave(opts)
	opts = opts or {}
	local interval = opts.interval or 60
	local uv = vim.uv or vim.loop
	if M._timer then
		M._timer:close()
		M._timer = nil
	end
	local group = vim.api.nvim_create_augroup("TabWorkspaceSessionAutosave", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			M.autosave({ notify = false })
		end,
	})
	M._timer = assert(uv.new_timer())
	M._timer:start(
		interval * 1000,
		interval * 1000,
		vim.schedule_wrap(function()
			M.autosave({ notify = opts.notify == true })
		end)
	)
end

--- 测试/退出用：停掉定时器
function M.stop_autosave()
	if M._timer then
		M._timer:close()
		M._timer = nil
	end
end

return M
