-- https://github.com/akinsho/toggleterm.nvim

return {
	"akinsho/toggleterm.nvim",
	version = "*",
	keys = {
		{ "<c-\\>" },
		{ "<c-l>", mode = { "n", "t" }, [[<cmd>lua require("config.toggle_terminal").init_or_toggle()<cr>]] },
	},
	config = function()
		-- 终端配置
		require("toggleterm").setup({
			-- 终端界面颜色加深
			shade_terminals = true,
			--终端大小设置
			size = function(term)
				if term.direction == "horizontal" then
					return 22
				elseif term.direction == "vertical" then
					return vim.o.columns * 0.4
				end
			end,
			open_mapping = [[<c-\>]], -- 开关键
			-- 终端样式设置vertical/horizontal/tab/float
			-- 从下面弹出
			direction = "horizontal",
			-- neovim更改目录时，终端自动切换目录
			autochdir = true,
		})

		-- 切换终端映射
		function _G.set_terminal_keymaps()
			local opts = { buffer = 0 }
			vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
			vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
			vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
			vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
			vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
			vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
		end

		-- if you only want these mappings for toggle term use term://*toggleterm#* instead
		vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
	end,
}
