-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	"nvim-neo-tree/neo-tree.nvim",
	keys = {
		{ "<leader>oe", desc = "文件树" },
		{ "<leader>ob", desc = "buffers" },
		{ "<leader>og", desc = "git" },
		{ "<leader>os", desc = "Symbols Explorer" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
		"MunifTanjim/nui.nvim",
		-- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
	},
	config = function()
		require("neo-tree").setup({
			close_if_last_window = true, -- Close Neo-tree if it is the last window left in the tab
			sources = {
				"filesystem",
				"buffers",
				"git_status",
				"document_symbols",
			},
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
			window = {
				position = "left",
				width = 30,
				mappings = {
					["<space>"] = {
						"toggle_node",
						nowait = true, -- disable `nowait` if you have existing combos starting with this char that you want to use
					},
					h = function(state)
						local node = state.tree:get_node()
						if (node.type == "directory" or node:has_children()) and node:is_expanded() then
							state.commands.toggle_node(state)
						else
							require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
						end
					end,
					l = function(state)
						local node = state.tree:get_node()
						if node.type == "directory" or node:has_children() then
							if not node:is_expanded() then
								state.commands.toggle_node(state)
							else
								require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
							end
						end
					end,
					-- 类目切换
					["<A-e>"] = function()
						vim.api.nvim_exec("Neotree focus filesystem left", true)
					end,
					["<A-b>"] = function()
						vim.api.nvim_exec("Neotree focus buffers left", true)
					end,
					["<A-g>"] = function()
						vim.api.nvim_exec("Neotree focus git_status left", true)
					end,
					["<A-s>"] = function()
						vim.api.nvim_exec("Neotree focus document_symbols left", true)
					end,
					-- 用系统默认文件管理器打开文件
					["O"] = "system_open",
					-- 打开文件但不丢失焦点
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
			},
			commands = {
				-- 用系统默认文件管理器打开文件
				system_open = function(state)
					local node = state.tree:get_node()
					local path = node:get_id()
					local os_name = jit.os
					if os_name == "OSX" then
						-- macOS: open file in default application in the background.
						vim.fn.jobstart({ "open", path }, { detach = true })
					elseif os_name == "Linux" then
						-- Linux: open file in default application
						vim.fn.jobstart({ "xdg-open", path }, { detach = true })
					elseif os_name == "Windows" then
						-- Windows: open file in Explorer
						local cmd
						if path:find(" ") then
							-- If the path contains spaces, enclose it in double quotes
							cmd = 'start explorer "' .. path .. '"'
						else
							cmd = "start explorer " .. path
						end
						vim.fn.jobstart(cmd, { detach = true })
					else
						print("Unsupported operating system: " .. os_name)
					end
				end,
			},
			event_handlers = {
				-- 打开文件自动关闭
				{
					event = "file_opened",
					handler = function(file_path)
						-- auto close
						-- vimc.cmd("Neotree close")
						-- OR
						require("neo-tree.command").execute({ action = "close" })
					end,
				},
				-- 隐藏光标
				{
					event = "neo_tree_buffer_enter",
					handler = function()
						vim.cmd("highlight! Cursor blend=100")
					end,
				},
				{
					event = "neo_tree_buffer_leave",
					handler = function()
						vim.cmd("highlight! Cursor guibg=#5f87af blend=0")
					end,
				},
			},
		})
		-- 设置快捷键打开文件树
		vim.keymap.set("n", "<leader>oe", "<cmd>Neotree toggle<cr>", { desc = "文件树" })
		vim.keymap.set("n", "<leader>ob", "<cmd>Neotree buffers toggle<cr>", { desc = "buffer" })
		vim.keymap.set("n", "<leader>og", "<cmd>Neotree git_status toggle<cr>", { desc = "git" })
		vim.keymap.set("n", "<leader>os", "<cmd>Neotree document_symbols toggle<cr>", { desc = "Symbols Explorer" })
	end,
}
