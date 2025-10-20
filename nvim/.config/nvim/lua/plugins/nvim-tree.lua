-- https://github.com/A7Lavinraj/fyler.nvim

return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	lazy = false,
	config = function()
		-- 主题风格推荐：gruvbox / catppuccin / tokyonight / onedark
		-- 如果你启用了 lualine，也会配色更协调。

		require("nvim-tree").setup({
			-- 📁 同步工作目录（很实用）
			sync_root_with_cwd = true,
			respect_buf_cwd = true,

			-- 📂 文件树行为
			hijack_cursor = true,
			sort_by = "case_sensitive",

			-- ✅ 侧边栏布局
			view = {
				width = 40, -- 稍宽一点，看得清
				side = "left", -- 靠左显示
				-- signcolumn = "no", -- 去掉左侧符号栏
				preserve_window_proportions = true,
				cursorline = true, -- 高亮当前文件
				float = { enable = false }, -- 不用浮动窗口
			},

			-- 🎨 渲染细节
			renderer = {
				highlight_git = true,
				highlight_opened_files = "name",
				root_folder_modifier = ":~", -- 显示 ~ 代替绝对路径

				indent_width = 2,
				indent_markers = {
					enable = true, -- 显示缩进线
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
							unstaged = "✗",
							staged = "✓",
							unmerged = "",
							untracked = "★",
							renamed = "➜",
							deleted = "",
							ignored = "◌",
						},
					},
				},
			},

			-- 🔍 文件过滤（显示隐藏文件）
			filters = {
				dotfiles = false,
				git_ignored = false,
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

			-- 🧠 文件诊断集成（LSP）
			diagnostics = {
				enable = true,
				show_on_dirs = true,
				icons = {
					hint = "󰌵",
					info = "",
					warning = "",
					error = "",
				},
			},

			-- 🔑 方便的行为
			actions = {
				open_file = {
					resize_window = true,
					quit_on_open = false,
				},
			},
		})
		vim.api.nvim_create_autocmd("QuitPre", {
			callback = function()
				local invalid_win = {}
				local wins = vim.api.nvim_list_wins()
				for _, w in ipairs(wins) do
					local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
					if bufname:match("NvimTree_") ~= nil then
						table.insert(invalid_win, w)
					end
				end
				if #invalid_win == #wins - 1 then
					-- Should quit, so we close all invalid windows.
					for _, w in ipairs(invalid_win) do
						vim.api.nvim_win_close(w, true)
					end
				end
			end,
		})

		vim.keymap.set("n", "<leader>ef", "<cmd>NvimTreeToggle<cr>", { desc = "文件管理器" })
	end,
}
