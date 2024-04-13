-- https://github.com/nvim-tree/nvim-tree.lua

return {
	"nvim-tree/nvim-tree.lua",
	event = "VeryLazy",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	keys = { "<leader>e", desc = "文件树" },
	config = function()
		require("nvim-tree").setup({
			hijack_cursor = true, -- 是否劫持光标
			select_prompts = true, -- 选择提示
			sort = {
				sorter = "case_sensitive", -- 排序器
			},
			view = {
				preserve_window_proportions = true, -- 保留窗口比例
				width = 35, -- 宽度
				-- number = true, -- 显示行号
				-- relativenumber = true, -- 显示相对行号
			},
			renderer = {
				group_empty = true, -- 空分组
			},
			filters = {
				dotfiles = true, -- 隐藏文件
			},
			diagnostics = { -- 诊断选项
				enable = true, -- 启用
				show_on_dirs = true, -- 在目录上显示
				show_on_open_dirs = true, -- 在打开的目录上显示
				debounce_delay = 50, -- 防抖延迟
				severity = { -- 严重程度
					min = vim.diagnostic.severity.HINT, -- 最小
					max = vim.diagnostic.severity.ERROR, -- 最大
				},
				icons = { -- 图标
					hint = " ", -- 提示
					info = " 󰌶", -- 信息
					warning = " 󰀪", -- 警告
					error = " 󰅚", -- 错误
				},
			},
		})

		keymap("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "文件树" })

		-- 当 nvim-tree 是最后一个窗口时自动关闭
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

		-- 打开文件自动关闭nvim-tree窗口
		vim.api.nvim_create_autocmd("BufLeave", {
			callback = function()
				if vim.bo.filetype == "NvimTree" then
					vim.cmd("NvimTreeClose")
				end
			end,
		})
	end,
}
