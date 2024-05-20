-- https://github.com/akinsho/toggleterm.nvim

return {
	"akinsho/toggleterm.nvim",
	version = "*",
	keys = {
		{ "<c-\\>" },
		{ "<leader>te", desc = "终端列表" },
		{ "<c-w>t", desc = "所有终端" },
	},
	config = function()
		require("toggleterm").setup({
			size = function(term)
				if term.direction == "horizontal" then
					return 20 -- 水平方向的终端宽度为 20 个字符
				elseif term.direction == "vertical" then
					return vim.o.columns * 0.4 -- 垂直方向的终端宽度为当前编辑器宽度的 40%
				end
			end,
			open_mapping = [[<c-\>]], -- 使用 Ctrl+\ 快捷键打开终端
			winbar = {
				enabled = true,
				name_formatter = function(term) -- 自定义窗口名称格式化函数
					return term.name
				end,
			},
		})
		function _G.set_terminal_keymaps()
			local opts = { buffer = 0 }
			vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
			vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
			vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
			vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
			vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
			vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
			vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
		end
		-- 如果你只想在 toggle term 时使用这些映射，使用 term://*toggleterm#* 替代
		vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

		vim.keymap.set("n", "<leader>te", "<cmd>TermSelect<cr>", { desc = "终端列表" })

		local init_or_toggle = function()
			vim.cmd([[ ToggleTermToggleAll ]])
			-- list current buffers
			local buffers = vim.api.nvim_list_bufs()
			-- check if toggleterm buffer exists. If not then create one by vim.cmd [[ exe 1 . "ToggleTerm" ]]
			local toggleterm_exists = false
			for _, buf in ipairs(buffers) do
				local buf_name = vim.api.nvim_buf_get_name(buf)
				if buf_name:find("toggleterm#") then
					toggleterm_exists = true
					break
				end
			end
			if not toggleterm_exists then
				vim.cmd([[ exe 1 . "ToggleTerm" ]])
			end
		end

		vim.keymap.set({ "n", "t" }, "<c-w>t", init_or_toggle, { desc = "所有终端" })
	end,
}
