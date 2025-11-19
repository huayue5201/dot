-- https://github.com/s1n7ax/nvim-window-picker

return {
	"s1n7ax/nvim-window-picker", -- for open_with_window_picker keymaps
	event = "WinNew",
	config = function()
		require("window-picker").setup({
			-- 你想要获得的提示类型
			-- 支持以下类型：
			-- 'statusline-winbar' | 'floating-big-letter' | 'floating-letter'
			-- 'statusline-winbar'：在 statusline 中显示，如果不行会显示在 winbar 中
			-- 'floating-big-letter'：在浮动窗口中显示大字母
			-- 'floating-letter'：在浮动窗口中显示字母
			-- 使用
			hint = "statusline-winbar",

			-- 当进入窗口选择模式时，状态栏会显示以下字母之一，你可以使用这些字母来选择窗口
			selection_chars = "FJDKSLA;CMRUEIWOQP",

			-- 以下是与选择器相关的配置
			picker_config = {
				-- 是否通过点击左键选择窗口
				handle_mouse_click = false,
				statusline_winbar_picker = {
					-- 你可以更改状态栏中的显示字符串。
					-- 它支持 '%' 格式化风格。例如 `return char .. ': %f'` 用来显示缓冲区的文件路径。有关详细信息，请参阅 :h 'stl'。
					selection_display = function(char, windowid)
						return "%=" .. char .. "%="
					end,

					-- 是否希望使用 winbar 代替 statusline
					-- "always" 意味着始终使用 winbar，
					-- "never" 意味着从不使用 winbar
					-- "smart" 意味着 cmdheight=0 时使用 winbar，cmdheight > 0 时使用 statusline
					use_winbar = "smart", -- "always" | "never" | "smart"
				},

				floating_big_letter = {
					-- 插件提供了许多大字母字体
					-- 字体会在请求时延迟加载
					-- 另外，用户可以传入一个字体表，使用自己定义的字体
					font = "ansi-shadow", -- ansi-shadow |
				},
			},

			-- 是否显示 'Pick window:' 提示
			show_prompt = true,

			-- 提示消息，提示用户输入
			prompt_message = "󰖳 Pick window: ",

			-- 如果你想手动过滤窗口，传入一个函数，接受两个参数。
			-- 你应该返回应该包含在选择中的窗口 ID
			-- 例如：-
			-- function(window_ids, filters)
			--    -- 过滤 window_ids
			--    -- 返回你想包含的窗口
			--    return {1000, 1001}
			-- end
			filter_func = nil,

			-- 以下过滤器仅在你使用默认过滤器时有效
			-- 如果你传入了自己的 "filter_func"，则由你自己负责
			filter_rules = {
				-- 当只有一个窗口可供选择时，直接使用该窗口，不提示用户选择
				autoselect_one = true,

				-- 是否将当前窗口包含在窗口选择中
				include_current_win = false,

				-- 是否包含标记为不可聚焦的窗口
				include_unfocusable_windows = false,

				-- 根据缓冲区选项进行过滤
				bo = {
					-- 如果文件类型是以下之一，窗口将被忽略
					filetype = { "pager", "neo-tree", "msgmore", "snacks_picker_input" },

					-- 如果缓冲区类型是以下之一，窗口将被忽略
					-- buftype = { "terminal" },
				},

				-- 根据窗口选项进行过滤
				wo = {},

				-- 如果文件路径包含以下名称，窗口将被忽略
				file_path_contains = {},

				-- 如果文件名包含以下名称，窗口将被忽略
				file_name_contains = {},
			},

			-- 你可以传入高亮名称或一个包含内容的表来设置高亮
			highlights = {
				enabled = true,
				statusline = {
					focused = {
						fg = "#ededed", -- 前景色
						bg = "#e35e4f", -- 背景色
						bold = true, -- 是否加粗
					},
					unfocused = {
						fg = "#ededed", -- 前景色
						bg = "#44cc41", -- 背景色
						bold = true, -- 是否加粗
					},
				},
				winbar = {
					focused = {
						fg = "#ededed", -- 前景色
						bg = "#e35e4f", -- 背景色
						bold = true, -- 是否加粗
					},
					unfocused = {
						fg = "#ededed", -- 前景色
						bg = "#44cc41", -- 背景色
						bold = true, -- 是否加粗
					},
				},
			},
		})

		vim.keymap.set("n", "<Leader>rw", function()
			-- 尝试加载 window-picker 插件
			local success, picker = pcall(require, "window-picker")
			if not success then
				print("You'll need to install window-picker to use this command.")
				return
			end
			-- 获取选中的窗口 ID
			local picked_window_id = picker.pick_window()
			if not picked_window_id then
				print("No window picked!")
				return
			end
			-- 获取该窗口的缓冲区 ID 和类型信息
			local buf_id = vim.api.nvim_win_get_buf(picked_window_id)
			local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf_id })
			local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf_id })
			local close_commands = require("user.utils").buf_keymaps["q"]
			-- 获取文件类型或缓冲区类型对应的关闭命令
			local command = close_commands[filetype ~= "" and filetype or buftype]
			-- 临时切换到选中的窗口，执行命令后切回
			local current_win = vim.api.nvim_get_current_win()
			vim.api.nvim_set_current_win(picked_window_id)
			-- 执行相应的命令或默认的 bdelete
			if command then
				if type(command) == "function" then
					command() -- 执行函数
				else
					vim.cmd(command) -- 执行命令字符串
				end
			else
				vim.cmd(string.format("bdelete %d", buf_id)) -- 默认 bdelete
			end
			-- 恢复原来的窗口
			vim.api.nvim_set_current_win(current_win)
		end, { silent = true, desc = "window: 删除选中的窗口（支持 close_commands 表）" })

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
		end, { silent = true, desc = "window: 选择一个窗口并切换" })

		vim.keymap.set("n", "<leader>sw", function()
			local success, picker = pcall(require, "window-picker")
			if not success then
				print("You'll need to install window-picker to use this command.")
				return
			end
			-- 选择一个窗口
			local window = picker.pick_window({
				include_current_win = false,
			})
			if window then
				local target_buffer = vim.fn.winbufnr(window)
				-- Set the target window to contain current buffer
				vim.api.nvim_win_set_buf(window, 0)
				-- Set current window to contain target buffer
				vim.api.nvim_win_set_buf(0, target_buffer)
				print("Swapped buffers!")
			else
				print("No window picked!")
			end
		end, { silent = true, desc = "window: 交换当前窗口与目标窗口的位置" })
	end,
}
