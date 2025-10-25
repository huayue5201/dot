-- https://github.com/Vigemus/iron.nvim

return {
	"Vigemus/iron.nvim",
	dependencies = { -- These are optional
		"nvim-treesitter/nvim-treesitter",
	},
	key = { "<leader>mr", desc = "Iron REPL" },
	config = function()
		local iron = require("iron.core")
		local view = require("iron.view")
		local common = require("iron.fts.common")

		iron.setup({
			config = {
				-- Whether a repl should be discarded or not
				scratch_repl = true,
				-- Your repl definitions come here
				repl_definition = {
					sh = {
						-- Can be a table or a function that
						-- returns a table (see below)
						command = { "zsh" },
					},
					python = {
						command = { "ipython" }, -- or { "ipython", "--no-autoindent" }
						format = common.bracketed_paste_python,
						block_dividers = { "# %%", "#%%" },
						env = { PYTHON_BASIC_REPL = "1" }, --this is needed for python3.13 and up.
					},
				},
				-- repl_open_cmd = view.bottom(20),
				repl_open_cmd = view.split.vertical.botright(50),
				-- repl_open_cmd = {
				-- 	view.split.vertical.rightbelow("%40"), -- cmd_1: open a repl to the right
				-- 	view.split.rightbelow("%25"), -- cmd_2: open a repl below
				-- },
			},
		})

		-- 在普通模式下：发送当前顶层非 module 语法节点
		-- 在可视模式下：发送选中代码块
		vim.keymap.set({ "n", "v" }, "<c-c><c-c>", function()
			local ts_utils = require("nvim-treesitter.ts_utils")
			local bufnr = vim.api.nvim_get_current_buf()
			local mode = vim.fn.mode()

			-- 如果是可视模式（'v' 或 'V'），取选中区域内容
			if mode == "v" or mode == "V" then
				-- 获取选区范围
				local start_row = vim.fn.getpos("'<")[2] - 1
				local start_col = vim.fn.getpos("'<")[3] - 1
				local end_row = vim.fn.getpos("'>")[2] - 1
				local end_col = vim.fn.getpos("'>")[3] - 1

				-- 获取选中文本
				local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
				local text = table.concat(lines, "\n")
				iron.send(nil, text)
				vim.notify("Sent visual selection to REPL", vim.log.levels.INFO)
				return
			end

			-- 否则（普通模式），按 Tree-sitter 找语法节点
			local cursor_node = ts_utils.get_node_at_cursor()
			if not cursor_node then
				vim.notify("No node under cursor", vim.log.levels.WARN)
				return
			end

			local top_non_module = nil
			local node = cursor_node
			while node do
				local type = node:type()
				if type ~= "module" then
					top_non_module = node
				end
				node = node:parent()
			end

			if not top_non_module then
				vim.notify("No non-module node found", vim.log.levels.WARN)
				return
			end

			local text = vim.treesitter.get_node_text(top_non_module, bufnr)
			iron.send(nil, text)
			vim.notify("Sent syntax block to REPL", vim.log.levels.INFO)
		end, { desc = "Send node or visual selection to REPL" })

		vim.keymap.set("n", "<space>mr", "<cmd>IronRepl<cr>")
		vim.keymap.set("n", "<space>mo", "<cmd>IronHide<cr>")
	end,
}
