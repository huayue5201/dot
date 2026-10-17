-- https://github.com/zbirenbaum/copilot.lua

return {
	"zbirenbaum/copilot.lua",
	dependencies = {
		"copilotlsp-nvim/copilot-lsp", -- (optional) for NES functionality
		init = function()
			vim.g.copilot_nes_debounce = 500
		end,
	},
	cmd = "Copilot",
	event = "InsertEnter",
	config = function()
		require("copilot").setup({
			panel = {
				enabled = true,
				auto_refresh = true,
				keymap = {
					jump_prev = "[[",
					jump_next = "]]",
					accept = "<CR>",
					refresh = "gr",
					open = "<M-p>", -- 原为 <M-CR>（终端普遍发不出）；panel.open 实际注册在插入模式
				},
				layout = {
					position = "bottom", -- | top | left | right | bottom |
					ratio = 0.4,
				},
			},
			suggestion = {
				enabled = true,
				auto_trigger = true,
				hide_during_completion = true,
				debounce = 15,
				trigger_on_accept = true,
				keymap = {
					accept = "<M-l>",
					accept_word = "<M-w>",
					accept_line = "<M-j>",
					next = "<M-]>",
					prev = "<M-[>",
					dismiss = "<C-]>",
					toggle_auto_trigger = false,
				},
			},
			-- NES（next-edit-suggestion）映射是「普通模式」，由 copilot-lsp 提供
			nes = {
				enabled = true,
				-- 注意：copilot.lua 当前版本不会把这个字段传给 copilot-lsp（实际是空转）
				auto_trigger = true,
				keymap = {
					accept_and_goto = "<M-k>", -- 原为 <c-cr>（多数终端无法发送 Ctrl+Enter）；不能用 <M-l>，会被 copilot 的模式校验误报为重复键
					accept = false,
					dismiss = "<Esc>",
				},
			},
		})

		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuOpen",
			callback = function()
				vim.b.copilot_suggestion_hidden = true
			end,
		})

		vim.api.nvim_create_autocmd("User", {
			pattern = "BlinkCmpMenuClose",
			callback = function()
				vim.b.copilot_suggestion_hidden = false
			end,
		})
	end,
}
