-- https://github.com/folke/noice.nvim

return {
	"folke/noice.nvim",
	event = "VeryLazy", -- keep for lazy loading
	keys = {
		{ "<leader>cn", "<cmd>Noice dismiss<cr>", desc = "关闭所有消息" },
		{ "<leader>on", "<cmd>Noice<cr>", desc = "打开历史消息" },
	},
	dependencies = {
		-- https://github.com/MunifTanjim/nui.nvim
		"MunifTanjim/nui.nvim",
	},
	config = function()
		require("noice").setup({
			lsp = {
				-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
			},
			-- you can enable a preset for easier configuration
			presets = {
				bottom_search = true, -- 使用经典的底部/？搜索栏
				command_palette = true, -- position the cmdline and popupmenu together
				long_message_to_split = true, -- long messages will be sent to a split
				inc_rename = true, -- enables an input dialog for inc-rename.nvim
				lsp_doc_border = true, -- add a border to hover docs and signature help
			},
		})

		-- lsp悬停文档滚动
		vim.keymap.set({ "n", "i", "s" }, "<c-u>", function()
			if not require("noice.lsp").scroll(4) then
				return "<c-u>"
			end
		end, { silent = true, expr = true })

		vim.keymap.set({ "n", "i", "s" }, "<c-d>", function()
			if not require("noice.lsp").scroll(-4) then
				return "<c-d>"
			end
		end, { silent = true, expr = true })
	end,
}
