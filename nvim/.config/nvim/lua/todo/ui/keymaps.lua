-- lua/todo/ui/keymaps.lua
local M = {}

---------------------------------------------------------------------
-- 键位设置函数
---------------------------------------------------------------------
function M.setup_keymaps(bufnr, win, ui_module)
	local core = require("todo.core")
	local constants = require("todo.ui.constants")
	local operations = require("todo.ui.operations")

	-- 安全的刷新函数
	local function safe_refresh()
		if ui_module and ui_module.refresh then
			ui_module.refresh(bufnr)
		end
	end

	local keymap_handlers = {
		close = function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end,
		refresh = function()
			local conceal = require("todo.ui.conceal")
			conceal.apply_conceal(bufnr)
			safe_refresh()
			vim.cmd("redraw")
		end,
		toggle = function()
			local lnum = vim.fn.line(".")
			core.toggle_line(bufnr, lnum)
			safe_refresh()
		end,
		toggle_insert = function()
			-- 退出插入模式
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
			local lnum = vim.fn.line(".")
			core.toggle_line(bufnr, lnum)
			safe_refresh()
			-- 重新进入插入模式
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
		end,
		toggle_selected = function()
			local changed = operations.toggle_selected_tasks(bufnr, win)
			safe_refresh()
			return changed
		end,
		new_task = function()
			operations.insert_task("新任务", 0, bufnr, ui_module)
		end,
		new_subtask = function()
			operations.insert_task("新任务", 2, bufnr, ui_module)
		end,
		new_sibling = function()
			operations.insert_task("新任务", 0, bufnr, ui_module)
		end,
	}

	-- 设置所有键位映射
	for key, mapping in pairs(constants.KEYMAPS) do
		local modes = type(mapping[1]) == "table" and mapping[1] or { mapping[1] }
		local keybind = mapping[2]
		local desc = mapping[3]
		local handler = keymap_handlers[key]

		if handler then
			for _, mode in ipairs(modes) do
				vim.keymap.set(mode, keybind, handler, { buffer = bufnr, desc = desc })
			end
		end
	end

	-- 添加额外的便利键位（可选）
	M.setup_extra_keymaps(bufnr, win, ui_module)
end

---------------------------------------------------------------------
-- 额外键位（可选）
---------------------------------------------------------------------
function M.setup_extra_keymaps(bufnr, win, ui_module)
	-- 切换窗口模式的快捷键
	vim.keymap.set("n", "<C-w>f", function()
		if ui_module and ui_module.switch_to_float then
			ui_module.switch_to_float(bufnr, win)
		end
	end, { buffer = bufnr, desc = "切换到浮窗模式" })

	vim.keymap.set("n", "<C-w>s", function()
		if ui_module and ui_module.switch_to_split then
			ui_module.switch_to_split(bufnr, win, "horizontal")
		end
	end, { buffer = bufnr, desc = "切换到水平分割" })

	vim.keymap.set("n", "<C-w>v", function()
		if ui_module and ui_module.switch_to_split then
			ui_module.switch_to_split(bufnr, win, "vertical")
		end
	end, { buffer = bufnr, desc = "切换到垂直分割" })

	-- 快速保存
	vim.keymap.set("n", "<C-s>", function()
		vim.cmd("write")
		if ui_module and ui_module.refresh then
			ui_module.refresh(bufnr)
		end
	end, { buffer = bufnr, desc = "保存TODO文件" })

	-- 快速导航
	vim.keymap.set("n", "]]", function()
		vim.cmd("normal! }")
		vim.cmd("normal! zz")
	end, { buffer = bufnr, desc = "下一个任务组" })

	vim.keymap.set("n", "[[", function()
		vim.cmd("normal! {")
		vim.cmd("normal! zz")
	end, { buffer = bufnr, desc = "上一个任务组" })

	-- 折叠相关
	vim.keymap.set("n", "za", function()
		vim.cmd("normal! za")
	end, { buffer = bufnr, desc = "切换折叠" })

	vim.keymap.set("n", "zR", function()
		vim.cmd("normal! zR")
	end, { buffer = bufnr, desc = "展开所有折叠" })

	vim.keymap.set("n", "zM", function()
		vim.cmd("normal! zM")
	end, { buffer = bufnr, desc = "折叠所有" })
end

---------------------------------------------------------------------
-- 窗口模式切换函数（需要在ui模块中实现）
---------------------------------------------------------------------
function M.create_window_switcher(ui_module)
	return {
		switch_to_float = function(bufnr, win)
			-- 获取当前文件路径
			local path = vim.api.nvim_buf_get_name(bufnr)
			if path and path ~= "" then
				-- 关闭当前窗口
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
				-- 重新以浮窗模式打开
				vim.schedule(function()
					ui_module.open_todo_file(path, "float", 1, { enter_insert = false })
				end)
			end
		end,

		switch_to_split = function(bufnr, win, direction)
			local path = vim.api.nvim_buf_get_name(bufnr)
			if path and path ~= "" then
				-- 关闭当前窗口
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_win_close(win, true)
				end
				-- 重新以分割模式打开
				vim.schedule(function()
					ui_module.open_todo_file(path, "split", 1, {
						enter_insert = false,
						split_direction = direction,
					})
				end)
			end
		end,
	}
end

return M
