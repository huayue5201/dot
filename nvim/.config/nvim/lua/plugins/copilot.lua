-- https://github.com/zbirenbaum/copilot.lua

return {
	"zbirenbaum/copilot.lua",
	dependencies = {
		"copilotlsp-nvim/copilot-lsp",
		init = function()
			-- debounce LSP 请求，防止频繁刷新
			vim.g.copilot_nes_debounce = 500
		end,
	},
	cmd = "Copilot",
	-- event = "InsertEnter",
	ft = { "lua", "python", "rust", "c", "go" },
	config = function()
		-- =====================================
		-- Copilot 配置
		-- =====================================
		require("copilot").setup({
			disable_limit_reached_message = true, --token 超过限制（rate limit / daily quota / usage limit）之后的提示设置
			nes = {
				enabled = true, -- 开启 Neovim inline ghost text
				inline = true, -- 行内显示
				keymap = {
					accept_and_goto = "<leader>p", -- 接受建议并跳到下一个
					accept = false, -- 不使用 Tab 接受
					dismiss = "<C-e>", -- 取消提示，不占用 Esc
				},
			},
			suggestion = {
				enabled = true, -- 自动显示建议
				auto_trigger = true, -- 插入模式自动触发
				debounce = 75, -- 防抖，减少性能开销
			},

			panel = {
				enabled = false, -- 不显示侧边面板
			},

			advanced = {
				inline_limit = 60, -- ghost text 最多显示 60 个字符，防止遮挡
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

		-- =====================================
		-- 常用快捷键
		-- =====================================
		vim.keymap.set("i", "<C-p>", function()
			require("copilot.suggestion").accept()
		end, { silent = true, desc = "Copilot: 接受建议" })

		vim.keymap.set("i", "<C-l>", function()
			require("copilot.suggestion").accept_line()
		end, { silent = true, desc = "Copilot: 接受整行建议" })

		vim.keymap.set("i", "<C-w>", function()
			require("copilot.suggestion").accept_word()
		end, { silent = true, desc = "Copilot: 接受单词建议" })

		vim.keymap.set("n", "<leader>tog", function()
			require("copilot.suggestion").toggle_auto_trigger()
		end, { silent = true, desc = "Copilot: 切换自动触发" })

		vim.keymap.set("i", "<C-k>", function()
			require("copilot.suggestion").next()
		end, { silent = true, desc = "Copilot: 下一个建议" })

		vim.keymap.set("i", "<C-j>", function()
			require("copilot.suggestion").prev()
		end, { silent = true, desc = "Copilot: 上一个建议" })
	end,
}
