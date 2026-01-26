-- https://github.com/nvim-tree/nvim-tree.lua
return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	lazy = false,
	config = function()
		local api = require("nvim-tree.api")
		-- 🎨 Git 状态颜色
		vim.api.nvim_set_hl(0, "NvimTreeGitDirty", { fg = "#e5c07b" }) -- 黄色
		vim.api.nvim_set_hl(0, "NvimTreeGitStaged", { fg = "#98c379" }) -- 绿色
		vim.api.nvim_set_hl(0, "NvimTreeGitMerge", { fg = "#e06c75" }) -- 红色
		vim.api.nvim_set_hl(0, "NvimTreeGitNew", { fg = "#61afef" }) -- 蓝色
		vim.api.nvim_set_hl(0, "NvimTreeGitRenamed", { fg = "#c678dd" }) -- 紫色
		vim.api.nvim_set_hl(0, "NvimTreeGitDeleted", { fg = "#be5046" }) -- 深红

		require("nvim-tree").setup({
			-- 📁 同步工作目录
			sync_root_with_cwd = true,
			respect_buf_cwd = true,
			update_focused_file = {
				enable = false,
				update_cwd = true,
				ignore_list = {},
			},

			-- 📂 文件树行为
			hijack_cursor = true,
			sort_by = "case_sensitive",

			-- ✅ 侧边栏布局
			view = {
				width = 40,
				side = "left",
				preserve_window_proportions = true,
				cursorline = true,
				float = { enable = false },
			},

			-- 🎨 渲染细节
			renderer = {
				highlight_git = true,
				highlight_opened_files = "name",
				root_folder_modifier = ":~",
				indent_width = 2,
				indent_markers = {
					enable = true,
					inline_arrows = false,
				},

				icons = {
					show = {
						file = true,
						folder = true,
						folder_arrow = false,
						git = true,
						hidden = true,
						modified = true,
						bookmarks = true,
					},
					glyphs = {
						folder = {
							default = "",
							open = "",
							empty = "",
							empty_open = "",
							symlink = "",
						},
						default = "󰈙",
						symlink = "",
						bookmark = "",
						modified = "",
						git = {
							deleted = "",
							renamed = "➜",
							unstaged = "󱅅",
							staged = "✓",
							unmerged = "",
							untracked = "★",
							ignored = "◌",
						},
					},
				},
			},

			-- 🔍 文件过滤
			filters = {
				dotfiles = true,
				git_ignored = true,
			},

			-- ✏️ 显示修改标记
			modified = {
				enable = true,
			},

			-- ⚙️ Git 集成
			git = {
				enable = true,
				ignore = false,
				timeout = 200,
			},
			-- 🔑 打开文件行为
			actions = {
				open_file = {
					resize_window = true,
					quit_on_open = false,
				},
			},
			on_attach = function(bufnr)
				local opts = { buffer = bufnr }
				api.config.mappings.default_on_attach(bufnr)
				-- function for left to assign to keybindings
				local lefty = function()
					local node_at_cursor = api.tree.get_node_under_cursor()
					-- if it's a node and it's open, close
					if node_at_cursor.nodes and node_at_cursor.open then
						api.node.open.edit()
					-- else left jumps up to parent
					else
						api.node.navigate.parent()
					end
				end
				-- function for right to assign to keybindings
				local righty = function()
					local node_at_cursor = api.tree.get_node_under_cursor()
					-- if it's a closed node, open it
					if node_at_cursor.nodes and not node_at_cursor.open then
						api.node.open.edit()
					end
				end
				vim.keymap.set("n", "h", lefty, opts)
				vim.keymap.set("n", "<Left>", lefty, opts)
				vim.keymap.set("n", "<Right>", righty, opts)
				vim.keymap.set("n", "l", righty, opts)
			end,
		})

		vim.api.nvim_create_autocmd("BufEnter", {
			nested = true,
			callback = function()
				if #vim.api.nvim_list_wins() == 1 and vim.bo.filetype == "NvimTree" then
					vim.cmd("quit")
				end
			end,
		})
		-- 🔑 快捷键
		vim.keymap.set("n", "<leader>ef", "<cmd>NvimTreeToggle<cr>", { desc = "文件管理器" })
	end,
}
