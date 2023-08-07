-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	"nvim-neo-tree/neo-tree.nvim",
	keys = {
		{ "<leader>e", "<cmd>Neotree toggle<cr>", desc = "NeoTree" },
		{ "\\e", "<cmd>Neotree reveal<cr>", desc = "NeoTree" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		-- https://github.com/nvim-tree/nvim-web-devicons
		"nvim-tree/nvim-web-devicons",
		"MunifTanjim/nui.nvim",
	},
	opts = {
		-- neotree是最后一个窗口时自动关闭
		close_if_last_window = true,
		event_handlers = {
			{
				event = "file_opened",
				-- 打开文件自动关闭neo-tree
				handler = function(file_path)
					--auto close
					require("neo-tree").close_all()
				end,
			},
		},
		-- sources列表
		sources = {
			"filesystem",
			"buffers",
			"git_status",
			-- "document_symbols",--  FIX: 不能用
		},
		-- wintar开启
		source_selector = {
			winbar = true,
			statusline = false,
			sources = {
				{ source = "filesystem", display_name = " 󰉓 Files" },
				{ source = "buffers", display_name = " Buffers" },
				{ source = "git_status", display_name = "󰊢 Git " },
			},
		},
		-- Nerd Fonts v3用户的配置,解决图标显示不全等问题
		default_component_configs = {
			icon = {
				folder_empty = "󰜌",
				folder_empty_open = "󰜌",
			},
			git_status = {
				symbols = {
					renamed = "󰁕",
					unstaged = "󰄱",
				},
			},
		},
		-- 窗口位置及大小
		window = {
			position = "left",
			width = 40,
			mapping_options = {
				noremap = true,
				nowait = true,
			},
			-- 快捷键配置
			mappings = {
				["<space>"] = {
					"toggle_node",
					nowait = true, -- disable `nowait` if you have existing combos starting with this char that you want to use
				},
				["<2-LeftMouse>"] = "open",
				["<cr>"] = "open",
				["<esc>"] = "revert_preview",
				["P"] = { "toggle_preview", config = { use_float = true } },
				["l"] = "focus_preview",
				["S"] = "open_split",
				["s"] = "open_vsplit",
				-- ["S"] = "split_with_window_picker",
				-- ["s"] = "vsplit_with_window_picker",
				["t"] = "open_tabnew",
				-- ["<cr>"] = "open_drop",
				-- ["t"] = "open_tab_drop",
				["w"] = "open_with_window_picker",
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
				["e"] = function()
					vim.api.nvim_exec("Neotree focus filesystem left", true)
				end,
				["b"] = function()
					vim.api.nvim_exec("Neotree focus buffers left", true)
				end,
				["g"] = function()
					vim.api.nvim_exec("Neotree focus git_status left", true)
				end,
			},
		},
		filesystem = {
			-- 这将使用操作系统级文件观察器来检测更改
			use_libuv_file_watcher = true,
			window = {
				mappings = {
					-- 运行命令
					["i"] = "run_command",
					-- 使用系统默认程序打开文件
					["<c-o>"] = "system_open",
					["<bs>"] = "navigate_up",
					["."] = "set_root",
					["<c-h>"] = "toggle_hidden",
					["/"] = "fuzzy_finder",
					["D"] = "fuzzy_finder_directory",
					["#"] = "fuzzy_sorter", -- fuzzy sorting using the fzy algorithm
					-- ["D"] = "fuzzy_sorter_directory",
					["f"] = "filter_on_submit",
					["<c-x>"] = "clear_filter",
					["[g"] = "prev_git_modified",
					["]g"] = "next_git_modified",
				},
				fuzzy_finder_mappings = { -- define keymaps for filter popup window in fuzzy_finder_mode
					["<down>"] = "move_cursor_down",
					["<C-n>"] = "move_cursor_down",
					["<up>"] = "move_cursor_up",
					["<C-p>"] = "move_cursor_up",
				},
			},
			commands = {
				-- 运行命令
				run_command = function(state)
					local node = state.tree:get_node()
					local path = node:get_id()
					vim.api.nvim_input(": " .. path .. "<Home>")
				end,
				-- 使用系统文件管理器查看文件
				system_open = function(state)
					local node = state.tree:get_node()
					local path = node:get_id()
					-- macOs: open file in default application in the background.
					-- Probably you need to adapt the Linux recipe for manage path with spaces. I don't have a mac to try.
					vim.api.nvim_command("silent !open -g " .. path)
					-- Linux: open file in default application
					vim.api.nvim_command(string.format("silent !xdg-open '%s'", path))
				end,
			},
		},
	},
}
