-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
		-- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
	},
	keys = {
		{ "<leader>oe", "<cmd>Neotree toggle<CR>", desc = "文件树" },
		{ "<leader>ls", "<cmd>Neotree document_symbols<CR>", desc = "查看符号树" },
	},
	config = function()
		vim.fn.sign_define("DiagnosticSignError", { text = " ", texthl = "DiagnosticSignError" })
		vim.fn.sign_define("DiagnosticSignWarn", { text = " ", texthl = "DiagnosticSignWarn" })
		vim.fn.sign_define("DiagnosticSignInfo", { text = " ", texthl = "DiagnosticSignInfo" })
		vim.fn.sign_define("DiagnosticSignHint", { text = "󰌵", texthl = "DiagnosticSignHint" })
		require("neo-tree").setup({
			close_if_last_window = true,
			event_handlers = {
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
			sources = {
				"filesystem",
				"buffers",
				"git_status",
				"document_symbols",
			},
			source_selector = {
				winbar = true, -- toggle to show selector on winbar
				statusline = false, -- toggle to show selector on statusline
				sources = { -- table
					{ source = "filesystem", display_name = " 󰉓 Files " },
					{ source = "buffers", display_name = " 󰈚 Buffers " },
					{ source = "git_status", display_name = " 󰊢 Git " },
					{ source = "document_symbols", display_name = "  Symbols" },
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
					["-"] = "open_split",
					["\\"] = "open_vsplit",
					["P"] = { "toggle_preview", config = { use_float = false, use_image_nvim = true } },
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
					["O"] = {
						command = function(state)
							local node = state.tree:get_node()
							local filepath = node.path
							local osType = os.getenv("OS")

							local command

							if osType == "Windows_NT" then
								command = "start " .. filepath
							elseif osType == "Darwin" then
								command = "open " .. filepath
							else
								command = "xdg-open " .. filepath
							end
							os.execute(command)
						end,
						desc = "open_with_system_defaults",
					},
				},
			},
		})
	end,
}
