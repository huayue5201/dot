---@diagnostic disable: need-check-nil, undefined-field
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons", -- optional, but recommended
		},
		lazy = false, -- neo-tree will lazily load itself
		config = function()
			local function open_grug_far(prefills)
				local grug_far = require("grug-far")

				if not grug_far.has_instance("explorer") then
					grug_far.open({ instanceName = "explorer" })
				else
					grug_far.get_instance("explorer"):open()
				end
				-- doing it seperately because multiple paths doesn't open work when passed with open
				-- updating the prefills without clearing the search and other fields
				grug_far.get_instance("explorer"):update_input_values(prefills, false)
			end

			---@diagnostic disable-next-line: missing-fields
			require("neo-tree").setup({
				close_if_last_window = true,
				popup_border_style = "rounded",
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
					},
				},
				filesystem = {
					window = {
						mappings = {
							["O"] = "system_open",
							["C"] = "open_and_clear_filter",
							-- map our new command to z
							z = "grug_far_replace",
						},
					},
				},
				commands = {
					open_and_clear_filter = function(state)
						local node = state.tree:get_node()
						if node and node.type == "file" then
							local file_path = node:get_id()
							-- reuse built-in commands to open and clear filter
							local cmds = require("neo-tree.sources.filesystem.commands")
							cmds.open(state)
							cmds.clear_filter(state)
							-- reveal the selected file without focusing the tree
							require("neo-tree.sources.filesystem").navigate(state, state.path, file_path)
						end
					end,

					system_open = function(state)
						local node = state.tree:get_node()
						local path = node:get_id()
						-- macOs: open file in default application in the background.
						vim.fn.jobstart({ "open", path }, { detach = true })
						-- Linux: open file in default application
						-- vim.fn.jobstart({ "xdg-open", path }, { detach = true })

						-- Windows: Without removing the file from the path, it opens in code.exe instead of explorer.exe
						local p
						local lastSlashIndex = path:match("^.+()\\[^\\]*$") -- Match the last slash and everything before it
						if lastSlashIndex then
							p = path:sub(1, lastSlashIndex - 1) -- Extract substring before the last slash
						else
							p = path -- If no slash found, return original path
						end
						vim.cmd("silent !start explorer " .. p)
					end,
					-- create a new neo-tree command
					grug_far_replace = function(state)
						local node = state.tree:get_node()
						local prefills = {
							-- also escape the paths if space is there
							-- if you want files to be selected, use ':p' only, see filename-modifiers
							paths = node.type == "directory" and vim.fn.fnameescape(
								vim.fn.fnamemodify(node:get_id(), ":p")
							) or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h")),
						}
						open_grug_far(prefills)
					end,
					-- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/fbb631e818f48591d0c3a590817003d36d0de691/doc/neo-tree.txt#L535
					grug_far_replace_visual = function(selected_nodes)
						local paths = {}
						for _, node in pairs(selected_nodes) do
							-- also escape the paths if space is there
							-- if you want files to be selected, use ':p' only, see filename-modifiers
							local path = node.type == "directory"
									and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
								or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h"))
							table.insert(paths, path)
						end
						local prefills = { paths = table.concat(paths, "\n") }
						open_grug_far(prefills)
					end,
				},
			})
			vim.keymap.set("n", "<leader>ef", "<Cmd>Neotree toggle<CR>")
			vim.keymap.set("n", "<leader>ee", "<Cmd>Neotree filesystem reveal<CR>")
			vim.keymap.set("n", "<leader>eb", "<Cmd>Neotree buffers toggle<CR>")
			vim.keymap.set("n", "<leader>eg", "<Cmd>Neotree git_status toggle<CR>")
		end,
	},
}
