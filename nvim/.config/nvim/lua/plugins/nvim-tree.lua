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

		map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "文件树" })

		-- 当 nvim-tree 是最后一个窗口时自动关闭
		local function tab_win_closed(winnr)
			local api = require("nvim-tree.api")
			local tabnr = vim.api.nvim_win_get_tabpage(winnr)
			local bufnr = vim.api.nvim_win_get_buf(winnr)
			local buf_info = vim.fn.getbufinfo(bufnr)[1]
			local tab_wins = vim.tbl_filter(function(w)
				return w ~= winnr
			end, vim.api.nvim_tabpage_list_wins(tabnr))
			local tab_bufs = vim.tbl_map(vim.api.nvim_win_get_buf, tab_wins)

			if buf_info.name:match(".*NvimTree_%d*$") then -- 关闭的是 nvim tree
				-- 在 :q 时关闭所有 nvim tree
				if not vim.tbl_isempty(tab_bufs) then -- 并且不是最后一个窗口（不会被下面的代码自动关闭）
					api.tree.close()
				end
			else -- 关闭的是普通的 buffer
				if #tab_bufs == 1 then -- 如果标签页中只有一个 buffer
					local last_buf_info = vim.fn.getbufinfo(tab_bufs[1])[1]
					if last_buf_info.name:match(".*NvimTree_%d*$") then -- 并且那个 buffer 是 nvim tree
						vim.schedule(function()
							if #vim.api.nvim_list_wins() == 1 then -- 如果是 vim 中最后一个 buffer
								vim.cmd("quit") -- 那就关闭整个 vim
							else -- 否则还有其他标签页
								vim.api.nvim_win_close(tab_wins[1], true) -- 那就只关闭标签页
							end
						end)
					end
				end
			end
		end

		vim.api.nvim_create_autocmd("WinClosed", {
			callback = function()
				local winnr = tonumber(vim.fn.expand("<amatch>"))
				vim.schedule_wrap(tab_win_closed(winnr))
			end,
			nested = true,
		})

		vim.api.nvim_create_autocmd("BufLeave", {
			callback = function()
				if vim.bo.filetype == "NvimTree" then
					vim.cmd("q")
				end
			end,
		})
	end,
}
