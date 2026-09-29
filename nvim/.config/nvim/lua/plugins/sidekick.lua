-- https://github.com/folke/sidekick.nvim
-- Copilot Next Edit Suggestions (NES) + 内置 AI CLI 终端
-- 依赖：copilot-language-server（已由 mason 安装）+ lsp/copilot.lua

return {
	"folke/sidekick.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		-- NES（Next Edit Suggestions）
		nes = {
			-- 默认开启；vim.g.sidekick_nes = false 可关
			debounce = 100,
		},
		-- AI CLI 终端
		cli = {
			win = {
				layout = "right", -- "float" | "left" | "bottom" | "top" | "right"
			},
			-- 会话持久化：你装了 tmux，想启用就取消注释
			mux = { backend = "tmux", enabled = true, create = "terminal" },
		},
	},
	keys = {
		-- NES：在普通模式跳转/应用下一个编辑建议（insert 模式已接入 blink，见 blink.lua）
		{
			"<tab>",
			function()
				if not require("sidekick").nes_jump_or_apply() then
					return "<Tab>"
				end
			end,
			expr = true,
			desc = "Sidekick: 跳转/应用 NES",
		},

		-- AI CLI 终端
		{
			"<c-.>",
			function()
				require("sidekick.cli").focus()
			end,
			mode = { "n", "t", "i", "x" },
			desc = "Sidekick: 聚焦 CLI",
		},
		{
			"<leader>aa",
			function()
				require("sidekick.cli").toggle()
			end,
			desc = "Sidekick: 切换 CLI",
		},
		{
			"<leader>as",
			function()
				require("sidekick.cli").select()
			end,
			desc = "Sidekick: 选择 CLI",
		},
		{
			"<leader>ad",
			function()
				require("sidekick.cli").close()
			end,
			desc = "Sidekick: 分离 CLI 会话",
		},
		{
			"<leader>at",
			function()
				require("sidekick.cli").send({ msg = "{this}" })
			end,
			mode = { "x", "n" },
			desc = "Sidekick: 发送光标处/选区（this）",
		},
		{
			"<leader>af",
			function()
				require("sidekick.cli").send({ msg = "{file}" })
			end,
			desc = "Sidekick: 发送当前文件",
		},
		{
			"<leader>av",
			function()
				require("sidekick.cli").send({ msg = "{selection}" })
			end,
			mode = { "x" },
			desc = "Sidekick: 发送选区",
		},
		{
			"<leader>ap",
			function()
				require("sidekick.cli").prompt()
			end,
			mode = { "n", "x" },
			desc = "Sidekick: 选择 prompt",
		},
		{
			"<leader>ac",
			function()
				require("sidekick.cli").toggle({ name = "claude", focus = true })
			end,
			desc = "Sidekick: 打开 Claude",
		},
	},
}
