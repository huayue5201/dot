-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	"nvim-neo-tree/neo-tree.nvim",
	keys = {
		{ "<leader>e", "<cmd>Neotree toggle<cr>", desc = "NeoTree" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
	},
	opts = {
		-- neotree是最后一个窗口时自动关闭
		close_if_last_window = true,
		-- sources列表
		sources = {
			"filesystem",
			"buffers",
			"git_status",
			-- "document_symbols",
		},
		-- wintar开启
		source_selector = {
			winbar = true,
			-- statusline = true,
			sources = {
				{ source = "filesystem", display_name = " 󰉓 Files " },
				{ source = "buffers", display_name = "  Buffers" },
				{ source = "git_status", display_name = " 󰊢 Git " },
			},
		},
		-- Nerd Fonts v3用户的配置
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
		window = {
			position = "left",
			width = 40,
			mapping_options = {
				noremap = true,
				nowait = true,
			},

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
			},
		},
	},
}
