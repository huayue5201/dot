-- 跳转落点守卫
--
-- 痛点：焦点在插件的「状态窗口」里（sqmeow 的抽屉/表格、neo-tree 等），
-- 打开文件或 LSP 跳转会把目标文件塞进这个窗口，插件的界面被顶掉。
-- Neovim 的 'winfixbuf' 只能拒绝（E1513），不能改道。
--
-- 做法：
--   * 插件侧把自己的窗口设为 'winfixbuf'，于是「原地被替换」再也不可能发生，
--     最差也只是报一个 E1513。
--   * 这里给会「跳到当前位置」的入口改道：跳转前先把焦点挪到最近用过的普通
--     编辑窗口，Neovim 自己就不会去动插件窗口。
--   * 插件 buffer 被 wipe 之后，锁在窗口上的 'winfixbuf' 要解开，否则那个窗口
--     会变成再也打不开文件的死窗口。

local M = {}

local api = vim.api

--- 由本模块识别的、需要保护的窗口（插件状态窗口）。
---@param ft string
---@return boolean
local function is_state_filetype(ft)
	return ft == "sqmeow-drawer"
		or ft == "sqmeow-result"
		or ft == "sqmeow-help"
		or ft == "neo-tree"
		or ft == "NvimTree"
end

--- 窗口是否是「状态窗口」：插件自己锁了它，或它显示的是插件界面。
---@param win integer
---@return boolean
function M.is_state_window(win)
	if not api.nvim_win_is_valid(win) then
		return false
	end
	if vim.fn.exists("&winfixbuf") == 1 and vim.wo[win].winfixbuf then
		return true
	end
	local ok, ft = pcall(function()
		return vim.bo[api.nvim_win_get_buf(win)].filetype
	end)
	return ok and is_state_filetype(ft)
end

--- 窗口是否可以充当跳转落点：普通 split，显示的是一个普通文件 buffer。
---@param win integer
---@return boolean
local function is_editor(win)
	if not api.nvim_win_is_valid(win) then
		return false
	end
	if api.nvim_win_get_config(win).relative ~= "" then
		return false
	end
	if M.is_state_window(win) then
		return false
	end
	local ok, buftype = pcall(function()
		return vim.bo[api.nvim_win_get_buf(win)].buftype
	end)
	return ok and buftype == ""
end

--- 最近一次停留过的普通编辑窗口。跳转优先落在它上面，其次才是别的编辑窗口。
---@type integer|nil
local last_editor = nil

--- 找跳转落点。
--- 找跳转落点。`create` 为真时，实在没有编辑窗口就新开一个（不开在插件侧边
--- 栏那一侧，免得把布局挤乱）。
---@param create? boolean
---@return integer|nil
function M.editing_window(create)
	if is_editor(last_editor) then
		return last_editor
	end
	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		if is_editor(win) then
			return win
		end
	end
	if create then
		local side = vim.tbl_filter(function(win)
			return api.nvim_win_is_valid(win) and M.is_state_window(win)
		end, api.nvim_tabpage_list_wins(0))
		local right = #side > 0 and api.nvim_win_get_position(side[1])[2] > 0
		vim.cmd(right and "topleft new" or "botright new")
		return api.nvim_get_current_win()
	end
	return nil
end

--- 把焦点从状态窗口挪回编辑区；已经在编辑区就什么都不做。
---@param create? boolean 没有编辑窗口时是否新开一个
---@return boolean 是否成功改道
function M.to_editor(create)
	local cur = api.nvim_get_current_win()
	if not M.is_state_window(cur) then
		return false
	end
	local win = M.editing_window(create)
	if not win then
		return false
	end
	api.nvim_set_current_win(win)
	return true
end

--- 「在当前窗口显示这个 buffer」：焦点在状态窗口时改成「在编辑区显示」。
--- 插件自己发的跳转（执行流、位置列表之类）走的就是这条路，
--- 不必每个调用点自己写守卫。
---@param set_buf fun(buf: integer)
---@param buf integer
---@return boolean redirected
local function retry_in_editor(set_buf, buf)
	if not M.to_editor(true) then
		return false
	end
	set_buf(buf)
	return true
end

--- 把「当前窗口换 buffer」的调用兜起来：被 'winfixbuf' 顶回来时不是报 E1513，
--- 而是把落点换到编辑区重试一次。
local function guard_buffer_switches()
	local set_current_buf = api.nvim_set_current_buf
	---@diagnostic disable-next-line: duplicate-set-field
	api.nvim_set_current_buf = function(buf)
		local ok, err = pcall(set_current_buf, buf)
		if ok then
			return
		end
		if not tostring(err):match("E1513") or not retry_in_editor(set_current_buf, buf) then
			error(err, 0)
		end
	end

	local set_win_buf = api.nvim_win_set_buf
	---@diagnostic disable-next-line: duplicate-set-field
	api.nvim_win_set_buf = function(win, buf)
		-- 只有「当前窗口」才改道；显式指定别的窗口是调用方自己的决定。
		local current = win == 0 or win == api.nvim_get_current_win()
		if not current or not M.is_state_window(api.nvim_get_current_win()) then
			return set_win_buf(win, buf)
		end
		local ok, err = pcall(set_win_buf, win, buf)
		if ok then
			return
		end
		if not tostring(err):match("E1513") or not retry_in_editor(function(b)
			set_win_buf(0, b)
		end, buf) then
			error(err, 0)
		end
	end
end

--- LSP 的跳转入口（`:help vim.lsp.util.show_document()`）自己决定把 buffer 塞进
--- 当前窗口，所以在这里先改道。
local function redirect_show_document()
	local orig = vim.lsp.util._show_document
	if not orig then
		return
	end
	---@diagnostic disable-next-line: duplicate-set-field
	vim.lsp.util._show_document = function(uri, range, position_encoding, opts)
		opts = opts or {}
		-- focus == false 的预览本来就不动焦点，也不用改道。
		if opts.focus ~= false then
			M.to_editor()
		end
		return orig(uri, range, position_encoding, opts)
	end
end

--- 记住窗口归属：sqmeow 的窗口在插件自己锁上之后才可能已经不是插件 buffer
--- （buffer 被 wipe、`:bdelete!` 之类），这时候补一次解锁。
local function watch_locks()
	local ours = {}

	api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
		group = api.nvim_create_augroup("CustomJumpRedirect", { clear = false }),
		callback = function()
			local win = api.nvim_get_current_win()
			local ft = vim.bo[api.nvim_win_get_buf(win)].filetype
			if is_state_filetype(ft) then
				ours[win] = true
			elseif ours[win] then
				ours[win] = nil
				if vim.fn.exists("&winfixbuf") == 1 and vim.wo[win].winfixbuf then
					vim.wo[win].winfixbuf = false
				end
			end
			if is_editor(win) then
				last_editor = win
			end
		end,
	})

	api.nvim_create_autocmd("WinClosed", {
		group = api.nvim_create_augroup("CustomJumpRedirect", { clear = false }),
		callback = function(args)
			local win = tonumber(args.match)
			ours[win] = nil
			if last_editor == win then
				last_editor = nil
			end
		end,
	})
end

function M.setup()
	if M._set_up then
		return
	end
	M._set_up = true
	watch_locks()
	redirect_show_document()
	guard_buffer_switches()
end

return M
