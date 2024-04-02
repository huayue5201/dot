-- https://github.com/akinsho/toggleterm.nvim

return {
	"akinsho/toggleterm.nvim",
	keys = { "<C-\\>", "<C-w>\\" },
	cmd = { "ToggleTerm", "ToggleTermToggleAll" },
	version = "*",
	config = function()
		-- 设置 ToggleTerm 插件
		require("toggleterm").setup({
			-- 设置终端窗口的大小
			size = function(term)
				if term.direction == "horizontal" then
					return 20
				elseif term.direction == "vertical" then
					return vim.o.columns * 0.4
				end
			end,
			-- 设置打开终端的快捷键
			open_mapping = [[<c-\>]],
			-- 控制终端窗口的背景色
			shade_terminals = true, -- 加深终端背景色
			-- 控制是否隐藏终端窗口的编号
			hide_numbers = true, -- 隐藏数字列
			-- 设置终端窗口的排列方向
			direction = "horizontal",
			-- 设置终端窗口的名称栏
			winbar = {
				enabled = true,
				-- 设置终端窗口名称的格式
				name_formatter = function(term) -- term: Terminal
					return term.name
				end,
			},
		})

		-- 按两次esc直接退出toggleterm
		local exitTerm = function()
			vim.cmd(":ToggleTerm")
		end
		keymap("t", "<esc><esc>", exitTerm)

		-- 设置快捷键以打开全部终端
		keymap(
			{ "n", "t", "i" },
			"<C-w>\\",
			'<cmd>lua  require("util.term_all").init_or_toggle() <cr>',
			{ desc = "全部终端" }
		)

		-- 设置终端内部的按键映射
		function _G.set_terminal_keymaps()
			local opts = { buffer = 0 }
			-- 设置终端内部按下 <esc> 键的行为
			vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
			-- 设置终端内部按下 <C-h> 键的行为
			vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
			vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
			vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
			vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
			vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
		end

		-- 如果您只希望这些映射适用于 ToggleTerm，请使用 term://*toggleterm#* 代替
		vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
	end,
}
