-- https://github.com/JuanZoran/Trans.nvim

return {
	"JuanZoran/Trans.nvim",
	build = function()
		require("Trans").install()
	end,
	dependencies = { "kkharji/sqlite.lua" },
	keys = {
		-- 可以换成其他你想映射的键
		{ "<leader>trl", mode = { "n", "v" }, desc = "󰊿  Translate" },
		{ "<leader>trp", mode = { "n", "v" }, desc = "  Auto Play" },
		-- 目前这个功能的视窗还没有做好，可以在配置里将view.i改成hover
		{ "<leader>tri", desc = "󰊿  Translate From Input" },
	},
	config = function()
		require("Trans").setup({
			-- dir = os.getenv("HOME") .. "/.vim/dict",
			frontend = {
				hover = {
					icon = {
						-- or use emoji
						list = "●", -- ● | ○ | ◉ | ◯ | ◇ | ◆ | ▪ | ▫ | ⬤ | 🟢 | 🟡 | 🟣 | 🟤 | 🟠| 🟦 | 🟨 | 🟧 | 🟥 | 🟪 | 🟫 | 🟩 | 🟦
						star = " ", -- ⭐ | ✴ | ✳ | ✲ | ✱ | ✰ | ★ | ☆ | 🌟 | 🌠 | 🌙 | 🌛 | 🌜 | 🌟 | 🌠 | 🌌 | 🌙 |
						notfound = "❔", --| ❓ | ❗ | ❕|
						yes = "✔", -- ✅ | ✔️ | ☑
						no = "", -- ❌ | ❎ | ✖ | ✘ | ✗ |
						cell = "■", -- ■  | □ | ▇ | ▏ ▎ ▍ ▌ ▋ ▊ ▉
						web = "󰖟", --🌍 | 🌎 | 🌏 | 🌐 |
						tag = "",
						pos = "",
						exchange = "",
						definition = "󰗊",
						translation = "󰊿",
					},
				},
			},
		})
		vim.keymap.set({ "n", "v" }, "<leader>trl", "<Cmd>Translate<CR>")
		vim.keymap.set({ "n", "v" }, "<leader>trp", "<Cmd>TransPlay<CR>") -- 自动发音选中或者光标下的单词
		vim.keymap.set("n", "<leader>tri", "<Cmd>TranslateInput<CR>")
	end,
}
