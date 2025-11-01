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

		-- 创建专门用于“发送到 REPL”高亮的样式
		vim.api.nvim_set_hl(0, "IronSendHighlight", {
			bg = "#3b4252", -- 背景色，可以改成更亮的颜色
			fg = "#88c0d0", -- 前景色（一般无效，因为是整块高亮）
			bold = true,
		})

		vim.keymap.set({ "n", "v" }, "<C-,>", function()
			local ts_utils = require("nvim-treesitter.ts_utils")
			local bufnr = vim.api.nvim_get_current_buf()
			local mode = vim.fn.mode()

			-- 🔹 高亮辅助函数
			local function highlight_range(start_row, start_col, end_row, end_col)
				local ns = vim.api.nvim_create_namespace("iron_send_highlight")
				for i = start_row, end_row do
					local s_col = (i == start_row) and start_col or 0
					local e_col = (i == end_row) and end_col or -1
					pcall(vim.api.nvim_buf_add_highlight, bufnr, ns, "IronSendHighlight", i, s_col, e_col)
				end
				vim.defer_fn(function()
					vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
				end, 2000)
			end

			-- 🔹 Visual 模式发送选中内容
			if mode == "v" or mode == "V" then
				local start_row = vim.fn.getpos("'<")[2] - 1
				local start_col = vim.fn.getpos("'<")[3] - 1
				local end_row = vim.fn.getpos("'>")[2] - 1
				local end_col = vim.fn.getpos("'>")[3] - 1
				local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
				local text = table.concat(lines, "\n")
				highlight_range(start_row, start_col, end_row, end_col)
				iron.send(nil, text)
				vim.notify("Sent visual selection to REPL", vim.log.levels.INFO)
				return
			end

			-- 🔹 Normal 模式下：即时选择 l/b
			vim.api.nvim_echo({
				{ "󰄛  Send to REPL → ", "Title" },
				{ "[l]", "Identifier" },
				{ " line ", "Normal" },
				{ "| ", "Normal" },
				{ "[b]", "Function" },
				{ " block", "Normal" },
			}, false, {})

			local ok, key = pcall(vim.fn.getcharstr)
			vim.api.nvim_echo({}, false, {}) -- 清理提示行
			if not ok then
				return
			end

			if key == "l" then
				local row = vim.api.nvim_win_get_cursor(0)[1] - 1
				local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
				highlight_range(row, 0, row, #line)
				iron.send(nil, line)
				vim.notify("Sent current line to REPL", vim.log.levels.INFO)
			elseif key == "b" then
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

				local start_row, start_col, end_row, end_col = top_non_module:range()
				local text = vim.treesitter.get_node_text(top_non_module, bufnr)
				highlight_range(start_row, start_col, end_row, end_col)
				iron.send(nil, text)
				vim.notify("Sent syntax block to REPL", vim.log.levels.INFO)
			else
				vim.notify("Cancelled", vim.log.levels.WARN)
			end
		end, { desc = "Send line, block, or visual selection to REPL" })

		vim.keymap.set("n", "<space>mr", "<cmd>IronRepl<cr>")
		vim.keymap.set("n", "<space>mo", "<cmd>IronHide<cr>")
	end,
}
