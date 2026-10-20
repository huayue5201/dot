-- https://github.com/CRAG666/betterTerm.nvim/tree/main
-- NOTE:https://github.com/nvzone/floaterm 浮动终端插件

return {
	"CRAG666/betterTerm.nvim",
	event = "VeryLazy",
	config = function()
		local betterTerm = require("betterTerm")

		betterTerm.setup({
			position = "bot",
			size = 18,
			jump_tab_mapping = "<A-$tab>",
			new_tab_hl = "Normal",
			new_tab_icon = " ",
		})

		-- Toggle the first terminal (ID defaults to index_base, which is 0)
		-- 只绑 normal 模式：terminal 模式里 <C-\> 必须留给 nvim 自己的
		-- <C-\><C-n>（退出终端插入模式）。
		-- 在终端里想切窗口：先 <Esc> 回到 normal，再按 <C-\>。
		vim.keymap.set("n", "<C-\\>", function()
			betterTerm.open()
		end, { desc = "Toggle terminal" })

		-- Open a specific terminal
		vim.keymap.set({ "n", "t" }, "<C-;>", function()
			betterTerm.open(1)
		end, { desc = "Toggle terminal 1" })

		-- Select a terminal to focus
		vim.keymap.set("n", "<leader>Ts", betterTerm.select, { desc = "终端: 选择" })

		-- Rename the current terminal
		vim.keymap.set("n", "<leader>Tn", betterTerm.rename, { desc = "终端: 重命名" })

		-- Toggle the tabs bar
		vim.keymap.set("n", "<leader>Tt", betterTerm.toggle_tabs, { desc = "终端: 切换标签栏" })

		-- Toggle the whole terminal window (all terminals, remembers last active)
		vim.keymap.set("n", "<leader>To", betterTerm.toggle_termwindow, { desc = "终端: 切换终端窗口" })

		-- Cycle between terminals
		vim.keymap.set({ "n", "t" }, "<C-PageUp>", function()
			betterTerm.cycle(1)
		end, { desc = "Cycle terminals right" })
		vim.keymap.set({ "n", "t" }, "<C-PageDown>", function()
			betterTerm.cycle(-1)
		end, { desc = "Cycle terminals left" })

		local function set_terminal_keymaps()
			local opts = { buffer = 0 }
			vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
			vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
			vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
			vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
			vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
			vim.opt_local.winfixbuf = true
		end

		-- 所有终端缓冲区：<Esc> 退出终端插入模式（裸 :terminal 也要有这条路）。
		-- 注意：:terminal 的 buffer 只有 buftype=terminal，'filetype' 是空的，
		-- 所以这里必须用 TermOpen 而不是 FileType。
		vim.api.nvim_create_autocmd("TermOpen", {
			callback = function(args)
				vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
					buffer = args.buf,
					desc = "终端: 退出插入模式",
				})
			end,
		})

		vim.api.nvim_create_autocmd("FileType", {
			pattern = "better_term",
			callback = function()
				set_terminal_keymaps()
			end,
		})
	end,
}
