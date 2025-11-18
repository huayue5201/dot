-- https://github.com/junegunn/fzf.vim

return {
	"junegunn/fzf.vim",
	event = "VeryLazy",
	dependencies = {
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

		-- 单独控制UI项,删除该项会和zsher配置同步
		vim.env.FZF_DEFAULT_OPTS = "--layout=reverse --border=none"

		-- vim.api.nvim_create_autocmd("User", {
		-- 	pattern = "FzfStatusLine",
		-- 	callback = funecho bufname()ction()
		-- 		vim.api.nvim_set_hl(0, "Fzf1", { fg = 161, bg = 251, ctermfg = 161, ctermbg = 251 })
		-- 		vim.api.nvim_set_hl(0, "Fzf2", { fg = 23, bg = 251, ctermfg = 23, ctermbg = 251 })
		-- 		vim.api.nvim_set_hl(0, "Fzf3", { fg = 237, bg = 251, ctermfg = 237, ctermbg = 251 })
		-- 		vim.opt_local.statusline = "%#Fzf1# > %#Fzf2#fz%#Fzf3#f"
		-- 	end,
		-- })

		vim.keymap.set("n", "<leader>ff", "<cmd>Files<cr>", { desc = "fzf：🔍 查找文件" })
		vim.keymap.set("n", "<leader>fb", "<cmd>Buffers<cr>", { desc = "fzf：📂 切换缓冲区" })
		vim.keymap.set("n", "<leader>fr", "<cmd>Rg<cr>", { desc = "fzf：🔎 使用 Ripgrep 搜索" })
		vim.keymap.set("n", "<leader>fm", "<cmd>Marks<cr>", { desc = "fzf：📌 查看书签" })
		vim.keymap.set("n", "<leader>fo", "<cmd>History<cr>", { desc = "fzf：🕘 查看历史记录" })
		vim.keymap.set("n", "<leader>fc", "<cmd>History:<cr>", { desc = "fzf：⌨️ 历史命令" })
	end,
}
