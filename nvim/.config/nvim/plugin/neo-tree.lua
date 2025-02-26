-- https://github.com/nvim-neo-tree/neo-tree.nvim

vim.g.later(function()
	vim.g.add({
		source = "nvim-neo-tree/neo-tree.nvim",
		depends = {
			"nvim-lua/plenary.nvim",
			"echasnovski/mini.icons",
			"MunifTanjim/nui.nvim",
		},
	})

	require("neo-tree").setup({
		close_if_last_window = true,
		open_files_do_not_replace_types = { "terminal", "trouble", "qf" },
		source_selector = {
			winbar = true,
			statusline = false,
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
				last_indent_marker = "└",
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
		window = {
			position = "left",
			width = 45,
			mapping_options = {
				noremap = true,
				nowait = true,
			},
			mappings = {
				["<space>"] = {
					"toggle_node",
					nowait = true, -- disable `nowait` if you have existing combos starting with this char that you want to use
				},
				["P"] = {
					"toggle_preview",
					config = {
						use_float = true,
						use_image_nvim = true,
						title = "文件预览",
					},
				},
				["<localleader>e"] = function()
					vim.api.nvim_exec2("Neotree focus filesystem left", { output = false })
				end,
				["<localleader>b"] = function()
					vim.api.nvim_exec2("Neotree focus buffers left", { output = false })
				end,
				["<localleader>g"] = function()
					vim.api.nvim_exec2("Neotree focus git_status left", { output = false })
				end,
				["O"] = "system_open",
			},
		},
		commands = {
			system_open = function(state)
				local node = state.tree:get_node()
				local path = node:get_id()

				-- 根据操作系统决定使用哪个命令
				if vim.fn.has("mac") == 1 then
					-- macOS: 使用 open 命令
					vim.fn.jobstart({ "open", path }, { detach = true })
				elseif vim.fn.has("unix") == 1 then
					-- Linux: 使用 xdg-open 命令
					vim.fn.jobstart({ "xdg-open", path }, { detach = true })
				elseif vim.fn.has("win32") == 1 then
					-- Windows: 使用 explorer 打开文件
					local p
					local lastSlashIndex = path:match("^.+()\\[^\\]*$") -- 匹配最后一个斜杠之前的路径
					if lastSlashIndex then
						p = path:sub(1, lastSlashIndex - 1) -- 提取路径
					else
						p = path -- 如果没有斜杠，则使用原路径
					end
					vim.cmd("silent !start explorer " .. p)
				else
					print("Unsupported OS")
				end
			end,
		},
		event_handlers = {
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

	vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "文件树" })
end)
