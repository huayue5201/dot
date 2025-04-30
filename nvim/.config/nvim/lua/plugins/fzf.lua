-- https://github.com/junegunn/fzf.vim

return {
	"junegunn/fzf.vim",
	event = "VeryLazy",
	dependencies = {
		"stevearc/aerial.nvim",
		"junegunn/fzf",
		build = function()
			vim.fn["fzf#install"]()
		end,
	},
	config = function()
		vim.g.fzf_preview_window = { "hidden", "ctrl-/" }
		-- 定义处理选中文件的函数
		local function build_quickfix_list(lines)
			-- 创建快速修复列表
			local items = vim.tbl_map(function(val)
				return { filename = val, lnum = 1 }
			end, lines)
			vim.fn.setqflist(items)
			vim.cmd("copen")
			vim.cmd("cc")
		end
		-- 设置 fzf 的操作
		vim.g.fzf_action = {
			["ctrl-q"] = build_quickfix_list, -- 绑定 ctrl-q 到自定义函数
			["ctrl-t"] = "tab split", -- 绑定 ctrl-t 到 "tab split"
			["ctrl-x"] = "split", -- 绑定 ctrl-x 到 "split"
			["ctrl-v"] = "vsplit", -- 绑定 ctrl-v 到 "vsplit"
		}

		-- vim.g.fzf_layout = {
		-- 	window = {
		-- 		width = 0.9, -- 宽度占 90% 屏幕宽度
		-- 		height = 0.6, -- 高度占 60% 屏幕高度
		-- 		xoffset = 0.5, -- 水平方向偏移 50%
		-- 		yoffset = 0.5, -- 垂直方向偏移 50%
		-- 		relative = false, -- 位置相对于当前窗口
		-- 		border = "rounded", -- 使用圆角边框
		-- 	},
		-- }

		-- vim.api.nvim_create_autocmd("User", {
		-- 	pattern = "FzfStatusLine",
		-- 	callback = function()
		-- 		vim.api.nvim_set_hl(0, "Fzf1", { fg = 161, bg = 251, ctermfg = 161, ctermbg = 251 })
		-- 		vim.api.nvim_set_hl(0, "Fzf2", { fg = 23, bg = 251, ctermfg = 23, ctermbg = 251 })
		-- 		vim.api.nvim_set_hl(0, "Fzf3", { fg = 237, bg = 251, ctermfg = 237, ctermbg = 251 })
		-- 		vim.opt_local.statusline = "%#Fzf1# > %#Fzf2#fz%#Fzf3#f"
		-- 	end,
		-- })

		vim.keymap.set("n", "<leader>ff", "<cmd>Files<cr>", { desc = "查找文件" })
		vim.keymap.set("n", "<leader>fb", "<cmd>Buffers<cr>", { desc = "切换缓冲区" })
		vim.keymap.set("n", "<leader>fg", "<cmd>Rg<cr>", { desc = "使用 Ripgrep 搜索" })
		vim.keymap.set("n", "<leader>fm", "<cmd>Marks<cr>", { desc = "查看书签" })
		vim.keymap.set("n", "<leader>fo", "<cmd>History<cr>", { desc = "查看历史记录" })
		vim.keymap.set("n", "<leader>fw", "<cmd>Windows<cr>", { desc = "窗口索引" })
		vim.keymap.set("n", "<leader>fc", "<cmd>History:<cr>", { desc = "历史命令" })
		vim.keymap.set("n", "<leader>fh", "<cmd>Helptags<cr>", { desc = "帮助文档" })
		vim.cmd([[nmap <silent> <leader>fl <cmd>call aerial#fzf()<cr>]])
	end,
}
