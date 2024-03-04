-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	"nvim-neo-tree/neo-tree.nvim",
	keys = {
		{ "<leader>oe", desc = "文件树" },
		{ "<leader>ob", desc = "buffers" },
		{ "<leader>og", desc = "git diff" },
		{ "<leader>os", desc = "符号树" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
		-- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
	},
	config = function()
		-- If you want icons for diagnostic errors, you'll need to define them somewhere:
		vim.fn.sign_define("DiagnosticSignError", { text = " ", texthl = "DiagnosticSignError" })
		vim.fn.sign_define("DiagnosticSignWarn", { text = " ", texthl = "DiagnosticSignWarn" })
		vim.fn.sign_define("DiagnosticSignInfo", { text = " ", texthl = "DiagnosticSignInfo" })
		vim.fn.sign_define("DiagnosticSignHint", { text = "󰌵", texthl = "DiagnosticSignHint" })

		require("neo-tree").setup({
			close_if_last_window = true, -- Close Neo-tree if it is the last window left in the tab
			sources = {
				"filesystem",
				"buffers",
				"git_status",
				"document_symbols",
			},
			source_selector = {
				winbar = true, -- toggle to show selector on winbar
				statusline = false, -- toggle to show selector on statusline
				show_scrolled_off_parent_node = false, -- boolean
				sources = { -- table
					{
						source = "filesystem", -- string
						display_name = " 󰉓 Files ", -- string | nil
					},
					{
						source = "buffers", -- string
						display_name = " 󰈚 Buffers ", -- string | nil
					},
					{
						source = "git_status", -- string
						display_name = " 󰊢 Git ", -- string | nil
					},
					{
						source = "document_symbols", -- string
						display_name = " 󰆧 Symbols ", -- string | nil
					},
				},
				content_layout = "start", -- string
				tabs_layout = "equal", -- string
				truncation_character = "…", -- string
				tabs_min_width = nil, -- int | nil
				tabs_max_width = nil, -- int | nil
				padding = 0, -- int | { left: int, right: int }
				separator = { left = "▏", right = "▕" }, -- string | { left: string, right: string, override: string | nil }
				separator_active = nil, -- string | { left: string, right: string, override: string | nil } | nil
				show_separator_on_edge = false, -- boolean
				highlight_tab = "NeoTreeTabInactive", -- string
				highlight_tab_active = "NeoTreeTabActive", -- string
				highlight_background = "NeoTreeTabInactive", -- string
				highlight_separator = "NeoTreeTabSeparatorInactive", -- string
				highlight_separator_active = "NeoTreeTabSeparatorActive", -- string
			},
			event_handlers = {
				-- 打开文件时自动关闭neotree
				{
					event = "file_opened",
					handler = function(file_path)
						-- auto close
						-- vimc.cmd("Neotree close")
						-- OR
						require("neo-tree.command").execute({ action = "close" })
					end,
				},
			},
			window = {
				position = "left",
				width = 35,
				mappings = {
					["P"] = { "toggle_preview", config = { use_float = false, use_image_nvim = true } },
					["<space>"] = {
						"toggle_node",
						nowait = true, -- disable `nowait` if you have existing combos starting with this char that you want to use
					},
					["e"] = function()
						vim.api.nvim_exec("Neotree focus filesystem left", true)
					end,
					["b"] = function()
						vim.api.nvim_exec("Neotree focus buffers left", true)
					end,
					["g"] = function()
						vim.api.nvim_exec("Neotree focus git_status left", true)
					end,
					["s"] = function()
						vim.api.nvim_exec("Neotree focus document_symbols left", true)
					end,
				},
			},
		})
		vim.keymap.set("n", "<space>oe", "<cmd>Neotree toggle<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>ob", "<cmd>Neotree buffers toggle<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>og", "<cmd>Neotree git_status toggle<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>os", "<cmd>Neotree document_symbols toggle<cr>", { silent = true, noremap = true })
	end,
}
