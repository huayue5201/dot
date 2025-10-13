-- https://github.com/nvim-neo-tree/neo-tree.nvim
-- 🚀 Neo-tree 文件管理器配置
return {
	"nvim-neo-tree/neo-tree.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-tree/nvim-web-devicons", -- 图标支持
		"3rd/image.nvim", -- 图片预览支持（需要安装 ImageMagick）
	},
	lazy = false, -- 不延迟加载
	config = function()
		-- 🧩 主配置
		require("neo-tree").setup({
			sources = { "filesystem", "buffers", "git_status" },
			source_selector = {
				winbar = true,
				statusline = false,
				sources = {
					{ source = "filesystem", display_name = "      files" },
					{ source = "buffers", display_name = "    buffers" },
					{ source = "git_status", display_name = "    git" },
				},
			},

			-- 当 Neo-tree 是最后一个窗口时自动关闭
			close_if_last_window = true,
			popup_border_style = "NC",
			enable_git_status = true,
			enable_diagnostics = true,

			-- 当打开文件时，不替换这些窗口类型
			open_files_do_not_replace_types = { "terminal", "trouble", "qf" },

			-- 默认组件配置
			default_component_configs = {
				indent = {
					indent_size = 2,
					padding = 1,
					with_markers = true,
					indent_marker = "│",
					last_indent_marker = "└",
					highlight = "NeoTreeIndentMarker",
					expander_collapsed = "",
					expander_expanded = "",
				},
				icon = {
					folder_closed = "",
					folder_open = "",
					folder_empty = "󰜌",
					provider = function(icon, node)
						if node.type == "file" or node.type == "terminal" then
							local ok, devicons = pcall(require, "nvim-web-devicons")
							if ok then
								local name = node.type == "terminal" and "terminal" or node.name
								local devicon, hl = devicons.get_icon(name)
								icon.text = devicon or icon.text
								icon.highlight = hl or icon.highlight
							end
						end
					end,
				},
				modified = { symbol = "[+]", highlight = "NeoTreeModified" },
				name = { use_git_status_colors = true },
				git_status = {
					symbols = {
						added = "",
						modified = "",
						deleted = "✖",
						renamed = "󰁕",
						untracked = "",
						ignored = "",
						unstaged = "󰄱",
						staged = "",
						conflict = "",
					},
				},
			},

			-- 🪟 Neo-tree 窗口映射
			window = {
				position = "left",
				width = 40,
				mapping_options = { noremap = true, nowait = true },
				mappings = {
					["<space>"] = "toggle_node",
					["<2-LeftMouse>"] = "open",
					["<cr>"] = "open",
					["<esc>"] = "cancel",
					["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
					["S"] = "open_split",
					["s"] = "open_vsplit",
					["t"] = "open_tabnew",
					["C"] = "close_node",
					["z"] = "close_all_nodes",
					["a"] = { "add", config = { show_path = "none" } },
					["A"] = "add_directory",
					["d"] = "delete",
					["r"] = "rename",
					["y"] = "copy_to_clipboard",
					["x"] = "cut_to_clipboard",
					["p"] = "paste_from_clipboard",
					["c"] = "copy",
					["m"] = "move",
					["q"] = "close_window",
					["R"] = "refresh",
					["?"] = "show_help",
					["i"] = "show_file_details",
					["<"] = "prev_source",
					[">"] = "next_source",
				},
			},

			-- 📁 文件系统视图配置
			filesystem = {
				filtered_items = {
					visible = false,
					hide_dotfiles = true,
					hide_gitignored = true,
					hide_hidden = true,
				},
				follow_current_file = {
					enabled = false,
					leave_dirs_open = false,
				},
				group_empty_dirs = false,
				hijack_netrw_behavior = "open_default",
				use_libuv_file_watcher = false,

				window = {
					mappings = {
						["<bs>"] = "navigate_up",
						["."] = "set_root",
						["H"] = "toggle_hidden",
						["/"] = "fuzzy_finder",
						["f"] = "filter_on_submit",
						["<c-x>"] = "clear_filter",
						["[g"] = "prev_git_modified",
						["]g"] = "next_git_modified",
						["o"] = "system_open", -- 打开系统文件浏览器
					},
				},

				-- 💻 自定义命令
				commands = {
					system_open = function(state)
						local node = state.tree:get_node()
						local path = node:get_id()

						-- ⚙️ 根据系统类型执行不同命令
						if vim.fn.has("mac") == 1 then
							vim.fn.jobstart({ "open", path }, { detach = true })
						elseif vim.fn.has("unix") == 1 then
							if vim.fn.executable("xdg-open") == 1 then
								vim.fn.jobstart({ "xdg-open", path }, { detach = true })
							else
								vim.notify("未找到 xdg-open，请安装 xdg-utils", vim.log.levels.ERROR)
							end
						elseif vim.fn.has("win32") == 1 then
							local p = path:gsub("/", "\\")
							vim.cmd("silent !start explorer " .. p)
						else
							vim.notify("当前系统不支持 system_open", vim.log.levels.WARN)
						end
					end,
				},
			},

			-- 📚 缓冲区视图配置
			buffers = {
				follow_current_file = { enabled = true, leave_dirs_open = false },
				group_empty_dirs = true,
				show_unloaded = true,
				window = { mappings = { ["d"] = "buffer_delete", ["bd"] = "buffer_delete" } },
			},

			-- 🧩 Git 状态视图配置
			git_status = {
				window = {
					mappings = {
						["A"] = "git_add_all",
						["gu"] = "git_unstage_file",
						["gU"] = "git_undo_last_commit",
						["ga"] = "git_add_file",
						["gr"] = "git_revert_file",
						["gc"] = "git_commit",
						["gp"] = "git_push",
						["gg"] = "git_commit_and_push",
					},
				},
			},

			-- 🎯 事件处理
			event_handlers = {
				-- 进入 Neo-tree buffer 时隐藏光标
				{
					event = "neo_tree_buffer_enter",
					handler = function()
						vim.cmd("highlight! Cursor blend=100")
					end,
				},
				-- 离开时恢复光标
				{
					event = "neo_tree_buffer_leave",
					handler = function()
						vim.cmd("highlight! Cursor guibg=#5f87af blend=0")
					end,
				},
				-- 打开文件时自动关闭树
				{
					event = "file_open_requested",
					handler = function()
						require("neo-tree.command").execute({ action = "close" })
					end,
				},
				-- 渲染后缓存 selector（避免频繁刷新出错）
				{
					event = "after_render",
					handler = function(state)
						if state and state.winid and vim.api.nvim_win_is_valid(state.winid) then
							vim.schedule(function()
								local ok, selector = pcall(require, "neo-tree.ui.selector")
								if ok and selector.get then
									_G.__cached_neo_tree_selector = selector.get()
								end
							end)
						end
					end,
				},
			},
		})

		-- 🧭 键位映射
		vim.keymap.set("n", "<leader>ef", "<Cmd>Neotree toggle<CR>", { desc = "切换文件树" })
		vim.keymap.set("n", "<leader>eb", "<Cmd>Neotree buffers toggle<CR>", { desc = "切换缓冲区树" })
		vim.keymap.set("n", "<leader>eg", "<Cmd>Neotree git_status toggle<CR>", { desc = "切换Git状态树" })
	end,
}
