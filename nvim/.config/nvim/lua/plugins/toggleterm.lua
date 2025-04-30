-- https://github.com/akinsho/toggleterm.nvim

return {
	"akinsho/toggleterm.nvim",
	keys = { "<c-\\>" },
	config = function()
		-- 设置高亮
		vim.api.nvim_set_hl(0, "ToggletermWinBar", {
			fg = "#ffffff",
			bg = "#FF4040", -- 整个 winbar 背景色
		})
		vim.api.nvim_set_hl(0, "ToggletermIcon", { fg = "#FF4040" }) -- 后续图标的颜色
		if not vim.g.term_counter then
			vim.g.term_counter = 1 -- 初始化计数器
		end
		require("toggleterm").setup({
			size = function(term)
				if term.direction == "horizontal" then
					return 15
				elseif term.direction == "vertical" then
					return vim.o.columns * 0.4
				end
			end,
			open_mapping = [[<c-\>]],
			persist_mode = true, -- 默认为 true，记住上次终端模式（普通/插入）
			autochdir = true, -- 若为 true，当 Neovim 更改当前目录时，下次打开终端会自动同步目录
			close_on_exit = true, -- 当进程退出时自动关闭终端窗口
			-- direction = "float",
			direction = "horizontal",
			float_opts = {
				border = "curved", -- 边框样式
				width = function()
					return vim.o.columns -- 使用当前屏幕宽度
				end,
				height = 18, -- 高度
				row = function()
					return vim.o.lines - 11 -- 固定在底部 (高度 10 + 1 行标题/边框)
				end,
				col = 0, -- 左对齐
				winblend = 20, -- 设置透明度
				title_pos = "center", -- 设置标题位置
			},
			winbar = {
				enabled = true,
				name_formatter = function(term)
					-- 如果没有设置 `term.id`，我们需要为每个终端设置唯一标识符
					if not term.id then
						term.id = vim.g.term_counter -- 设置终端的 id 为当前计数器
						vim.g.term_counter = vim.g.term_counter + 1 -- 递增计数器
					end

					-- 使用 `term.id` 作为终端编号
					local terminal_name = "term." .. term.id
					-- 组合高亮的图标与终端名称
					return "%#ToggletermIcon#"
						.. "" -- 
						.. "%*"
						.. "%#ToggletermWinBar#"
						.. " "
						.. terminal_name
						.. "%*"
						.. "%#ToggletermIcon#"
						.. ""
						.. "%*"
				end,
			},
			responsiveness = {
				-- 控制窗口宽度在小于该值时自动从左右并排变为上下堆叠
				-- 默认值为 0（关闭该特性）
				horizontal_breakpoint = 135,
			},
		})

		vim.keymap.set({ "t", "n" }, "<c-w>\\", "<cmd>ToggleTermToggleAll<cr>", { desc = "Toggle terminal" })
		vim.keymap.set({ "t", "n" }, "<a-t>", "<cmd>TermSelect<cr>", { desc = " select a terminal" })
		vim.keymap.set({ "t", "n" }, "<a-\\>", "<cmd>TermNew<cr>", { desc = " select a terminal" })

		function _G.set_terminal_keymaps()
			local opts = { buffer = 0 }
			vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
			vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
			vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
			vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
			vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
			vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
		end
		-- ✅ 只作用于 toggleterm 终端
		vim.api.nvim_create_autocmd("TermOpen", {
			pattern = "term://*toggleterm#*",
			callback = function()
				set_terminal_keymaps()
			end,
		})
	end,
}
