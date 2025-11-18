local M = {}

M.last_search_count = ""
M.cursor_autocmd_id = nil

-- 判断光标是否在当前搜索匹配行
local function cursor_in_match()
	local search_pattern = vim.fn.getreg("/")
	if search_pattern == "" or search_pattern == vim.fn.getreg("1") then
		return false
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line, col = cursor[1], cursor[2]

	-- 使用Vim的searchpos来确保与搜索行为一致
	local saved_cursor = vim.api.nvim_win_get_cursor(0)
	vim.api.nvim_win_set_cursor(0, { line, 0 })

	local match_start = vim.fn.searchpos(search_pattern, "c", line)[2]
	local match_end = match_start + vim.fn.matchstr(vim.fn.getline(line), search_pattern):len() - 1

	vim.api.nvim_win_set_cursor(0, saved_cursor)

	if match_start > 0 then
		return col + 1 >= match_start and col + 1 <= match_end
	end
	return false
end

-- 刷新状态栏
function M.update_status()
	local sc = vim.fn.searchcount({ recompute = 1, maxcount = 9999 })
	local current = sc.current or 0
	local total = sc.total or 0
	if total > 0 then
		M.last_search_count = string.format("[%d/%d]", current, total)
		vim.cmd("redrawstatus")
		-- 确保光标监听处于活动状态
		M.start_cursor_autocmd()
	else
		M.clear_status()
	end
end

-- 清理状态栏并删除光标移动自动命令
function M.clear_status()
	if M.last_search_count ~= "" then
		M.last_search_count = ""
		vim.cmd("redrawstatus")
		M.stop_cursor_autocmd()
	end
end

-- 停止光标监听
function M.stop_cursor_autocmd()
	if M.cursor_autocmd_id then
		pcall(vim.api.nvim_del_autocmd, M.cursor_autocmd_id)
		M.cursor_autocmd_id = nil
	end
end

-- 创建临时光标移动自动命令，检测离开匹配行
function M.start_cursor_autocmd()
	-- 如果已经有监听器，先停止它
	M.stop_cursor_autocmd()

	M.cursor_autocmd_id = vim.api.nvim_create_autocmd("CursorMoved", {
		callback = function()
			if M.last_search_count == "" then
				M.stop_cursor_autocmd()
				return
			end

			-- 检查光标是否仍在匹配行
			if not cursor_in_match() then
				M.clear_status()
			end
		end,
	})
end

-- 设置搜索完成监听
function M.setup_autocmd()
	local group = vim.api.nvim_create_augroup("SearchStatus", { clear = true })

	-- 当用户退出命令行搜索后显示计数并启用光标监听
	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = group,
		callback = function(event)
			if event.match == "/" or event.match == "?" then
				-- 延迟执行，确保搜索已经完成
				vim.defer_fn(function()
					M.update_status()
				end, 10)
			end
		end,
	})

	-- 插入模式开始时清除搜索状态
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function()
			M.clear_status()
		end,
	})

	-- 文本改变时检查搜索状态
	vim.api.nvim_create_autocmd("TextChanged", {
		group = group,
		callback = function()
			if M.last_search_count ~= "" then
				M.update_status()
			end
		end,
	})
end

-- 搜索跳转键刷新计数
function M.setup_keymaps()
	local search_keys = { "n", "N", "*", "#", "g*", "g#" }
	for _, key in ipairs(search_keys) do
		vim.keymap.set("n", key, function()
			local count = vim.v.count1
			local cmd = (count > 1 and count or "") .. key
			vim.cmd("normal! " .. cmd)
			-- 延迟更新状态，确保跳转已完成
			vim.defer_fn(function()
				M.update_status()
			end, 10)
		end, { noremap = true, silent = true })
	end

	-- ESC 清理状态栏并取消搜索高亮
	vim.keymap.set("n", "<Esc>", function()
		M.clear_status()
		vim.cmd("nohlsearch")
	end, { noremap = true, silent = true })

	-- Ctrl-C 也清理状态
	vim.keymap.set("n", "<C-c>", function()
		M.clear_status()
		vim.cmd("nohlsearch")
	end, { noremap = true, silent = true })
end

-- 初始化模块
function M.setup()
	M.setup_keymaps()
	M.setup_autocmd()
end

-- 获取状态栏显示字符串
function M.get()
	return M.last_search_count
end

return M
