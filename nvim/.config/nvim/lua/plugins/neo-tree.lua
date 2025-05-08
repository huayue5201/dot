-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	"nvim-neo-tree/neo-tree.nvim",
	keys = {
		{ "<leader>ef", desc = "File Explorer" },
		{ "<leader>eb", desc = "Buffers (root dir)" },
		{ "<leader>eg", desc = "Git Status" },
		-- { "<leader>es", desc = "Symbols" },
		{ "<leader>ed", desc = "打开当前文件根目录" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
		"s1n7ax/nvim-window-picker",
	},
	config = function()
		require("neo-tree").setup({
			close_if_last_window = false, -- Close Neo-tree if it is the last window left in the tab
			popup_border_style = "rounded",
			enable_git_status = true,
			enable_diagnostics = true,
			open_files_do_not_replace_types = { "terminal", "trouble", "qf" }, -- when opening files, do not use windows containing these filetypes or buftypes
			open_files_using_relative_paths = false,
			sort_case_insensitive = false, -- used when sorting files and directories in the tree
			sort_function = nil, -- use a custom function for sorting files and directories in the tree
			-- sort_function = function (a,b)
			--       if a.type == b.type then
			--           return a.path > b.path
			--       else
			--           return a.type > b.type
			--       end
			--   end , -- this sorts files and directories descendantly
			sources = {
				"filesystem",
				"buffers",
				"git_status",
				-- "document_symbols",
			},
			source_selector = {
				winbar = true,
				statusline = false,
				sources = {
					{ source = "filesystem" },
					{ source = "buffers" },
					{ source = "git_status" },
					-- { source = "document_symbols" },
				},
			},
			default_component_configs = {
				container = {
					enable_character_fade = true,
				},
				indent = {
					indent_size = 2,
					padding = 1, -- extra padding on left hand side
					-- indent guides
					with_markers = true,
					indent_marker = "│",
					last_indent_marker = "╰", --└
					highlight = "NeoTreeIndentMarker",
					-- expander config, needed for nesting files
					with_expanders = nil, -- if nil and file nesting is enabled, will enable expanders
					expander_collapsed = "",
					expander_expanded = "",
					expander_highlight = "NeoTreeExpander",
				},
				icon = {
					folder_closed = "",
					folder_open = "",
					folder_empty = "󰜌",
					provider = function(icon, node, state) -- default icon provider utilizes nvim-web-devicons if available
						if node.type == "file" or node.type == "terminal" then
							local success, web_devicons = pcall(require, "nvim-web-devicons")
							local name = node.type == "terminal" and "terminal" or node.name
							if success then
								local devicon, hl = web_devicons.get_icon(name)
								icon.text = devicon or icon.text
								icon.highlight = hl or icon.highlight
							end
						end
					end,
					-- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
					-- then these will never be used.
					default = "*",
					highlight = "NeoTreeFileIcon",
				},
				modified = {
					symbol = "[+]",
					highlight = "NeoTreeModified",
				},
				name = {
					trailing_slash = false,
					use_git_status_colors = true,
					highlight = "NeoTreeFileName",
				},
				git_status = {
					symbols = {
						-- Change type
						added = "", -- or "✚", but this is redundant info if you use git_status_colors on the name
						modified = "", -- or "", but this is redundant info if you use git_status_colors on the name
						deleted = "✖", -- this can only be used in the git_status source
						renamed = "󰁕", -- this can only be used in the git_status source
						-- Status type
						untracked = "",
						ignored = "",
						unstaged = "󰄱",
						staged = "",
						conflict = "",
					},
				},
				-- If you don't want to use these columns, you can set `enabled = false` for each of them individually
				file_size = {
					enabled = true,
					width = 12, -- width of the column
					required_width = 64, -- min width of window required to show this column
				},
				type = {
					enabled = true,
					width = 10, -- width of the column
					required_width = 122, -- min width of window required to show this column
				},
				last_modified = {
					enabled = true,
					width = 20, -- width of the column
					required_width = 88, -- min width of window required to show this column
				},
				created = {
					enabled = true,
					width = 20, -- width of the column
					required_width = 110, -- min width of window required to show this column
				},
				symlink_target = {
					enabled = false,
				},
			},
			-- A list of functions, each representing a global custom command
			-- that will be available in all sources (if not overridden in `opts[source_name].commands`)
			-- see `:h neo-tree-custom-commands-global`
			commands = {
				toggle_debug = toggle_debug_from_neotree,
				system_open = function(state)
					local node = state.tree:get_node()
					local path = node:get_id()

					-- 获取当前操作系统
					local os_type = vim.fn.has("macunix") == 1 and "macOS"
						or vim.fn.has("unix") == 1 and "Linux"
						or vim.fn.has("win32") == 1 and "Windows"
						or "Unknown"

					-- 根据操作系统执行相应的打开文件命令
					if os_type == "macOS" then
						-- macOS: 使用 "open" 打开文件
						vim.fn.jobstart({ "open", path }, { detach = true })
					elseif os_type == "Linux" then
						-- Linux: 使用 "xdg-open" 打开文件
						vim.fn.jobstart({ "xdg-open", path }, { detach = true })
					elseif os_type == "Windows" then
						-- Windows: 使用 "explorer" 打开文件
						local lastSlashIndex = path:match("^.+()\\[^\\]*$") -- 匹配最后的斜杠以及之前的部分
						local p
						if lastSlashIndex then
							p = path:sub(1, lastSlashIndex - 1) -- 提取出最后一个斜杠前的路径
						else
							p = path -- 如果没有斜杠，使用原始路径
						end
						vim.cmd("silent !start explorer " .. p)
					else
						-- 未知操作系统类型
						print("Unsupported OS")
					end
				end,
				avante_add_files = function(state)
					local node = state.tree:get_node()
					local filepath = node:get_id()
					local relative_path = require("avante.utils").relative_path(filepath)

					local sidebar = require("avante").get()

					local open = sidebar:is_open()
					-- 确保 avante 侧边栏已打开
					if not open then
						require("avante.api").ask()
						sidebar = require("avante").get()
					end

					sidebar.file_selector:add_selected_file(relative_path)

					-- 删除 neo tree 缓冲区
					if not open then
						sidebar.file_selector:remove_selected_file("neo-tree filesystem [1]")
					end
				end,
			},
			window = {
				position = "left",
				width = 45,
				mapping_options = {
					nowait = true,
				},
				mappings = {
					["+"] = "avante_add_files",
					["w"] = function(state)
						local node = state.tree:get_node()
						local success, picker = pcall(require, "window-picker")
						if not success then
							print(
								"You'll need to install window-picker to use this command: https://github.com/s1n7ax/nvim-window-picker"
							)
							return
						end
						local picked_window_id = picker.pick_window()
						if picked_window_id then
							vim.api.nvim_set_current_win(picked_window_id)
							vim.cmd("edit " .. vim.fn.fnameescape(node.path))
						end
					end,
					["O"] = "system_open",
					["<2-LeftMouse>"] = "open",
					["<cr>"] = "open",
					["<esc>"] = "cancel", -- close preview or floating neo-tree window
					-- Read `# Preview Mode` for more information
					["<l>"] = "focus_preview",
					["S"] = "open_split",
					["s"] = "open_vsplit",
					-- ["S"] = "split_with_window_picker",
					-- ["s"] = "vsplit_with_window_picker",
					["t"] = "open_tabnew",
					-- ["<cr>"] = "open_drop",
					-- ["t"] = "open_tab_drop",
					-- ["w"] = "open_with_window_picker",
					--["P"] = "toggle_preview", -- enter preview mode, which shows the current node without focusing
					["C"] = "close_node",
					-- ['C'] = 'close_all_subnodes',
					["z"] = "close_all_nodes",
					--["Z"] = "expand_all_nodes",
					["a"] = {
						"add",
						-- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
						-- some commands may take optional config options, see `:h neo-tree-mappings` for details
						config = {
							show_path = "none", -- "none", "relative", "absolute"
						},
					},
					["A"] = "add_directory", -- also accepts the optional config.show_path option like "add". this also supports BASH style brace expansion.
					["d"] = "delete",
					["r"] = "rename",
					["b"] = "rename_basename",
					["y"] = "copy_to_clipboard",
					["x"] = "cut_to_clipboard",
					["p"] = "paste_from_clipboard",
					["c"] = "copy", -- takes text input for destination, also accepts the optional config.show_path option like "add":
					-- ["c"] = {
					--  "copy",
					--  config = {
					--    show_path = "none" -- "none", "relative", "absolute"
					--  }
					--}
					["m"] = "move", -- takes text input for destination, also accepts the optional config.show_path option like "add".
					["q"] = "close_window",
					["R"] = "refresh",
					["?"] = "show_help",
					["<"] = "prev_source",
					[">"] = "next_source",
					["i"] = "show_file_details",
					-- ["i"] = {
					--   "show_file_details",
					--   -- format strings of the timestamps shown for date created and last modified (see `:h os.date()`)
					--   -- both options accept a string or a function that takes in the date in seconds and returns a string to display
					--   -- config = {
					--   --   created_format = "%Y-%m-%d %I:%M %p",
					--   --   modified_format = "relative", -- equivalent to the line below
					--   --   modified_format = function(seconds) return require('neo-tree.utils').relative_date(seconds) end
					--   -- }
					-- },
					["P"] = {
						"toggle_preview",
						config = {
							use_float = true,
							-- use_image_nvim = true,
							-- title = 'Neo-tree Preview',
						},
					},
					["<tab>"] = function(state)
						local node = state.tree:get_node()
						if require("neo-tree.utils").is_expandable(node) then
							state.commands["toggle_node"](state)
						else
							state.commands["open"](state)
							vim.cmd("Neotree reveal")
						end
					end,
				},
				nesting_rules = {},
				filesystem = {
					filtered_items = {
						visible = false, -- when true, they will just be displayed differently than normal items
						hide_dotfiles = true,
						hide_gitignored = true,
						hide_hidden = true, -- only works on Windows for hidden files/directories
						hide_by_name = {
							--"node_modules"
						},
						hide_by_pattern = { -- uses glob style patterns
							--"*.meta",
							--"*/src/*/tsconfig.json",
						},
						always_show = { -- remains visible even if other settings would normally hide it
							--".gitignored",
						},
						always_show_by_pattern = { -- uses glob style patterns
							--".env*",
						},
						never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
							--".DS_Store",
							--"thumbs.db"
						},
						never_show_by_pattern = { -- uses glob style patterns
							--".null-ls_*",
						},
					},
					follow_current_file = {
						enabled = false, -- This will find and focus the file in the active buffer every time
						--               -- the current file is changed while the tree is open.
						leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
					},
					group_empty_dirs = false, -- when true, empty folders will be grouped together
					hijack_netrw_behavior = "open_default", -- netrw disabled, opening a directory opens neo-tree
					-- in whatever position is specified in window.position
					-- "open_current",  -- netrw disabled, opening a directory opens within the
					-- window like netrw would, regardless of window.position
					-- "disabled",    -- netrw left alone, neo-tree does not handle opening dirs
					use_libuv_file_watcher = false, -- This will use the OS level file watchers to detect changes
					-- instead of relying on nvim autocmd events.
					window = {
						mappings = {
							["<bs>"] = "navigate_up",
							["."] = "set_root",
							["H"] = "toggle_hidden",
							["/"] = "fuzzy_finder",
							["D"] = "fuzzy_finder_directory",
							["#"] = "fuzzy_sorter", -- fuzzy sorting using the fzy algorithm
							-- ["D"] = "fuzzy_sorter_directory",
							["f"] = "filter_on_submit",
							["<c-x>"] = "clear_filter",
							["[g"] = "prev_git_modified",
							["]g"] = "next_git_modified",
							["o"] = {
								"show_help",
								nowait = false,
								config = { title = "Order by", prefix_key = "o" },
							},
							["oc"] = { "order_by_created", nowait = false },
							["od"] = { "order_by_diagnostics", nowait = false },
							["og"] = { "order_by_git_status", nowait = false },
							["om"] = { "order_by_modified", nowait = false },
							["on"] = { "order_by_name", nowait = false },
							["os"] = { "order_by_size", nowait = false },
							["ot"] = { "order_by_type", nowait = false },
							-- ['<key>'] = function(state) ... end,
						},
						fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
							["<down>"] = "move_cursor_down",
							["<C-n>"] = "move_cursor_down",
							["<up>"] = "move_cursor_up",
							["<C-p>"] = "move_cursor_up",
							["<esc>"] = "close",
							-- ['<key>'] = function(state, scroll_padding) ... end,
						},
					},

					commands = {}, -- Add a custom command or override a global one using the same function name
				},
				buffers = {
					follow_current_file = {
						enabled = true, -- This will find and focus the file in the active buffer every time
						--              -- the current file is changed while the tree is open.
						leave_dirs_open = false, -- `false` closes auto expanded dirs, such as with `:Neotree reveal`
					},
					group_empty_dirs = true, -- when true, empty folders will be grouped together
					show_unloaded = true,
					window = {
						mappings = {
							["d"] = "buffer_delete",
							["bd"] = "buffer_delete",
							["<bs>"] = "navigate_up",
							["."] = "set_root",
							["o"] = {
								"show_help",
								nowait = false,
								config = { title = "Order by", prefix_key = "o" },
							},
							["oc"] = { "order_by_created", nowait = false },
							["od"] = { "order_by_diagnostics", nowait = false },
							["om"] = { "order_by_modified", nowait = false },
							["on"] = { "order_by_name", nowait = false },
							["os"] = { "order_by_size", nowait = false },
							["ot"] = { "order_by_type", nowait = false },
						},
					},
				},
				git_status = {
					window = {
						position = "float",
						mappings = {
							["A"] = "git_add_all",
							["gu"] = "git_unstage_file",
							["ga"] = "git_add_file",
							["gr"] = "git_revert_file",
							["gc"] = "git_commit",
							["gp"] = "git_push",
							["gg"] = "git_commit_and_push",
							["o"] = {
								"show_help",
								nowait = false,
								config = { title = "Order by", prefix_key = "o" },
							},
							["oc"] = { "order_by_created", nowait = false },
							["od"] = { "order_by_diagnostics", nowait = false },
							["om"] = { "order_by_modified", nowait = false },
							["on"] = { "order_by_name", nowait = false },
							["os"] = { "order_by_size", nowait = false },
							["ot"] = { "order_by_type", nowait = false },
						},
					},
				},
			},
			event_handlers = {
				{
					event = "file_open_requested",
					handler = function()
						-- auto close
						-- vim.cmd("Neotree close")
						-- OR
						require("neo-tree.command").execute({ action = "close" })
					end,
				},
				{
					event = "after_render",
					handler = function(state)
						if state.current_position == "left" or state.current_position == "right" then
							vim.api.nvim_win_call(state.winid, function()
								local str = require("neo-tree.ui.selector").get()
								if str then
									_G.__cached_neo_tree_selector = str
								end
							end)
						end
					end,
				},
			},
		})

		vim.keymap.set("n", "<leader>ef", function()
			require("neo-tree.command").execute({
				toggle = true,
				source = "filesystem",
				position = "left",
			})
		end, { silent = true, desc = "File Explorer" })

		vim.keymap.set("n", "<leader>eb", function()
			require("neo-tree.command").execute({
				toggle = true,
				source = "buffers",
				position = "left",
			})
		end, { silent = true, desc = "Buffers (root dir)" })

		vim.keymap.set("n", "<leader>eg", function()
			require("neo-tree.command").execute({
				toggle = true,
				source = "git_status",
				position = "left",
			})
		end, { silent = true, desc = "Git Status" })

		-- vim.keymap.set("n", "<leader>es", function()
		-- 	require("neo-tree.command").execute({
		-- 		toggle = true,
		-- 		source = "document_symbols",
		-- 		position = "left",
		-- 	})
		-- end, { silent = true, desc = "Symbols" })

		vim.keymap.set(
			"n",
			"<leader>ed",
			"<cmd>Neotree filesystem reveal left<cr>",
			{ silent = true, desc = "打开当前文件根目录" }
		)
	end,
}
