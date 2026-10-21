-- https://github.com/huayue5201/nvim-window-picker
--
-- zpack 本地目录模式：vim.pack 把下面的绝对路径当作安装源，clone 一份副本到
-- stdpath("data")/site/pack/core/opt/nvim-window-picker，nvim 实际加载的是副本。
-- 所以改完 ~/neovim-plugins/nvim-window-picker 并 push 后，要执行
-- :PackLocalSync（<leader>zp）让副本跟上新 rev，再重启生效。
-- 必须写绝对路径：lua/core/pack_local.lua 靠本地插件的 src 以 "/" 开头来识别它。
return {
	dir = "/Users/lijia/neovim-plugins/nvim-window-picker",
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
				handle_mouse_click = true,
				statusline_winbar_picker = {
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

				-- 外部工具（herdr 等）目标的浮动列表，bento 风格
				floating_list = {
					-- 浮窗位置：'top-left' | 'top-right' | 'middle-left'
					-- | 'middle-right' | 'bottom-left' | 'bottom-right' | 'center'
					position = "middle-right",
					-- 距所选边缘的偏移（单位：格）
					offset_x = 1,
					offset_y = 0,
					-- 边框，见 :h winborder
					border = "none",
					-- 跳转字母与信息之间的间距
					label_padding = 1,
					-- 跳转字母的高亮组
					label_hl = "DiagnosticVirtualTextHint",
					-- 浮窗背景高亮组；'WindowPickerWindow' 的 bg=NONE 使其透明
					window_bg = "WindowPickerWindow",
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
					filetype = { "pager", "msgmore", "snacks_picker_input" },

					-- 如果缓冲区类型是以下之一，窗口将被忽略
					buftype = {},
				},

				-- 根据窗口选项进行过滤
				wo = {},

				-- 如果文件路径包含以下名称，窗口将被忽略
				-- BqfPreviewFloatWin / BqfPreviewTitle 是 nvim-bqf 的预览浮窗，
				-- 它们是 focusable 的（mouse 含 'a' 时），必须按 buffer 名排除
				file_path_contains = { "BqfPreviewFloatWin" },

				-- 如果文件名包含以下名称，窗口将被忽略
				file_name_contains = {},
			},
		})

		vim.keymap.set("n", "<leader>cw", function()
			-- 尝试加载 window-picker 插件
			local ok, picker = pcall(require, "window-picker")
			if not ok then
				print("You'll need to install window-picker to use this command.")
				return
			end
			-- 选择窗口
			local picked_window_id = picker.pick_window()
			if not picked_window_id then
				print("No window picked!")
				return
			end
			-- 记录当前窗口
			local current_win = vim.api.nvim_get_current_win()
			-- 确保目标窗口有效
			if not vim.api.nvim_win_is_valid(picked_window_id) then
				print("Picked window is no longer valid.")
				return
			end
			-- 切换到目标窗口
			vim.api.nvim_set_current_win(picked_window_id)
			-- ⭐ 使用统一关闭逻辑
			require("core.navigation").smart_close(picked_window_id)
			-- 恢复原窗口
			if vim.api.nvim_win_is_valid(current_win) then
				vim.api.nvim_set_current_win(current_win)
			end
		end, { silent = true, desc = "窗口: 关闭选中的窗口（统一 smart_close）" })

		vim.keymap.set("n", "<leader>ww", function()
			local success, picker = pcall(require, "window-picker")
			if not success then
				print("You'll need to install window-picker to use this command.")
				return
			end
			-- 跨工具选择：nvim 窗口 + herdr 外部 pane + ghostty 终端
			-- 各源在对应环境不可用时会自动跳过（herdr 看 HERDR_ENV，ghostty 仅 macOS）
			-- herdr scope: "tab" | "workspace" | "all"
			-- respect_zoom 仅 scope="tab" 生效：tab 被 zoom 时
			--   只列出可见 pane；若被 zoom 的是别的 pane（nvim 被藏）则不弹选择器
			-- ghostty scope: "tab" | "window" | "all"（默认 all）；nvim 自身终端
			--   会自动排除，tab/window 识别不到自身时退回 all
			local target, abort_info = picker.pick_target({
				sources = {
					nvim = true,
					herdr = { scope = "tab", respect_zoom = true },
					ghostty = { scope = "all" },
				},
			})
			if not target then
				if abort_info and abort_info.aborted then
					print(
						"herdr tab 被 zoom 到其他 pane，选择器已跳过（source: "
							.. abort_info.source
							.. "）"
					)
				else
					print("No window picked!")
				end
				return
			end
			-- herdr pane / ghostty terminal 在 pick_target 内部已 focus，无需再切换
			if target.kind == "nvim" then
				vim.api.nvim_set_current_win(target.window)
			end
		end, { silent = true, desc = "窗口: 选择 nvim 窗口 / herdr pane" })

		vim.keymap.set("n", "<leader>ws", function()
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
		end, { silent = true, desc = "窗口: 与目标窗口交换 buffer" })
	end,
}
