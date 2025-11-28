local M = {}

M.last_search_count = ""
M.cursor_autocmd_id = nil

-- 判断光标是否在当前搜索匹配行
local function cursor_in_match()
	local search_pattern = vim.fn.getreg("/")
	if search_pattern == "" then
		return false
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local line, col = cursor[1] - 1, cursor[2] -- Lua 是 0-based 索引

	-- 使用更可靠的方法检查光标是否在匹配上
	local line_content = vim.api.nvim_get_current_line()

	-- 使用 Vim 的 match 函数来定位匹配
	local match_start = vim.fn.match(line_content, search_pattern)
	if match_start < 0 then
		return false
	end

	-- 获取匹配的结束位置
	local match_end = vim.fn.matchend(line_content, search_pattern) - 1

	return col >= match_start and col <= match_end
end

-- 刷新状态栏
function M.update_status()
	local ok, sc = pcall(vim.fn.searchcount, { recompute = 1, maxcount = 9999 })
	if not ok then
		M.clear_status()
		return
	end

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
	-- 如果已经有监听器且仍在运行，不重复创建
	if M.cursor_autocmd_id then
		return
	end

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

			-- 安全执行命令，捕获可能出现的错误
			local ok, err = pcall(vim.cmd, "normal! " .. cmd)
			if not ok then
				-- 如果是"模式未找到"错误，温和处理而非抛出Lua错误
				if string.find(tostring(err), "E486:") then
					vim.notify("搜索模式未找到: " .. vim.fn.getreg("/"), vim.log.levels.WARN)
					-- 仍然更新状态，显示无匹配
					M.clear_status()
				else
					-- 其他错误重新抛出
					error(err)
				end
			else
				-- 延迟更新状态，确保跳转已完成
				vim.defer_fn(function()
					M.update_status()
				end, 10)
			end
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
