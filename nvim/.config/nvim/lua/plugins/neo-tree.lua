---@diagnostic disable: need-check-nil, undefined-field
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"3rd/image.nvim",
		"nvim-tree/nvim-web-devicons", -- optional, but recommended
		"saifulapm/neotree-file-nesting-config", -- 文件嵌套规则插件
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
			-- ========== 基础设置 ==========
			sources = {
				"filesystem",
				"buffers",
				"git_status",
				"document_symbols",
			},
			close_if_last_window = true,
			popup_border_style = "rounded",

			-- ========== 根节点设置（来自你提供的配置）==========
			hide_root_node = true, -- 隐藏根节点
			retain_hidden_root_indent = true, -- 保留隐藏根节点的缩进

			-- ========== 源选择器 ==========
			source_selector = {
				winbar = true,
				statusline = false,
				sources = {
					{ source = "filesystem" },
					{ source = "buffers" },
					{ source = "git_status" },
					{ source = "document_symbols" },
				},
			},

			-- ========== 窗口设置 ==========
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

			-- ========== 默认组件配置 ==========
			default_component_configs = {
				indent = {
					with_expanders = true,
					expander_collapsed = "",
					expander_expanded = "",
				},
			},

			-- ========== 文件系统设置 ==========
			filesystem = {
				-- 过滤项设置
				filtered_items = {
					show_hidden_count = false,
					never_show = {
						".DS_Store",
					},
				},
				window = {
					mappings = {
						["O"] = "system_open",
						["C"] = "open_and_clear_filter",
						["h"] = function(state)
							local node = state.tree:get_node()
							if node.type == "directory" and node:is_expanded() then
								require("neo-tree.sources.filesystem").toggle_directory(state, node)
							else
								require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
							end
						end,
						["l"] = function(state)
							local node = state.tree:get_node()
							if node.type == "directory" then
								if not node:is_expanded() then
									require("neo-tree.sources.filesystem").toggle_directory(state, node)
								elseif node:has_children() then
									require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
								end
							end
						end,
						-- map our new command to z
						z = "grug_far_replace",
					},
				},
			},

			-- ========== 自定义命令 ==========
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
					-- macOS: open file in default application in the background.
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

		-- 应用文件嵌套规则（来自 neotree-file-nesting-config 插件）
		local opts = require("neo-tree").config
		if opts and opts.filesystem then
			opts.nesting_rules = require("neotree-file-nesting-config").nesting_rules
			require("neo-tree").setup(opts)
		end

		-- ========== 快捷键映射 ==========
		vim.keymap.set("n", "<leader>ef", "<Cmd>Neotree toggle<CR>")
		vim.keymap.set("n", "<leader>ee", "<Cmd>Neotree filesystem reveal<CR>")
		vim.keymap.set("n", "<leader>eb", "<Cmd>Neotree buffers toggle<CR>")
		vim.keymap.set("n", "<leader>eg", "<Cmd>Neotree git_status toggle<CR>")
		vim.keymap.set("n", "<leader>es", "<Cmd>Neotree document_symbols toggle<CR>")
	end,
}
