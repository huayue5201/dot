-- https://github.com/s1n7ax/nvim-window-picker

return {
	"s1n7ax/nvim-window-picker", -- for open_with_window_picker keymaps
	event = "VeryLazy",
	version = "2.*",
	config = function()
		-- 配置 window-picker 插件
		require("window-picker").setup({
			hint = "statusline-winbar",
			filter_rules = {
				include_current_win = false, -- 不包括当前窗口
				autoselect_one = true, -- 自动选择一个窗口
				-- 过滤规则：按文件类型和缓冲区类型过滤
				bo = {
					-- 如果文件类型是以下之一，窗口将被忽略
					filetype = { "neo-tree", "neo-tree-popup", "notify" },
					-- 如果缓冲区类型是以下之一，窗口将被忽略
					buftype = { "terminal", "quickfix" },
				},
			},
		})

		vim.keymap.set("n", "<Leader>rw", function()
			local success, picker = pcall(require, "window-picker")
			if not success then
				print("You'll need to install window-picker to use this command.")
				return
			end
			-- 选择窗口
			local picked_window_id = picker.pick_window()
			if picked_window_id then
				-- 获取缓冲区 ID
				local buf_id = vim.api.nvim_win_get_buf(picked_window_id)
				-- 执行 :bd 命令来删除缓冲区
				vim.cmd("BufRemove" .. buf_id)
				print("Buffer deleted!")
			else
				print("No window picked!")
			end
		end, { silent = true, desc = "删除选中的窗口的缓冲区" })

		vim.keymap.set("n", "<Leader>w", function()
			local success, picker = pcall(require, "window-picker")
			if not success then
				print("You'll need to install window-picker to use this command.")
				return
			end
			local picked_window_id = picker.pick_window()
			if picked_window_id then
				vim.api.nvim_set_current_win(picked_window_id)
			else
				print("No window picked!")
			end
		end, { silent = true, desc = "选择一个窗口并切换" })
	end,
}
