-- https://github.com/olimorris/codecompanion.nvim

return {
	"olimorris/codecompanion.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"saghen/blink.cmp",
	},
	config = function()
		require("codecompanion").setup({
			-- 语言.
			language = "Chinese",
			-- 适配器配置
			adapters = {
				http = {
					deepseek = function()
						return require("codecompanion.adapters").extend("openai_compatible", {
							env = {
								url = "https://api.deepseek.com",
								api_key = os.getenv("DEEPSEEK_API_KEY"), -- 从环境变量读取
								chat_url = "/v1/chat/completions",
							},
							schema = {
								model = {
									default = "deepseek-v4-pro", -- 或 "deepseek-coder"
								},
							},
						})
					end,
				},
			},
			-- 交互配置
			interactions = {
				chat = {
					adapter = "deepseek", -- 使用 DeepSeek
				},
				inline = {
					adapter = "deepseek",
				},
				cmd = {
					adapter = "deepseek",
				},
			},
			-- 可选：默认提示库
			prompts = {
				custom = {
					-- 示例：定义一个代码审查提示
					review = {
						prompt = "Please review the following code and suggest improvements:",
						interaction = "inline",
						opts = {
							is_default = true,
						},
					},
				},
			},
		})

		-- 快捷键映射（以 <Leader>a 为前缀）
		vim.keymap.set(
			{ "n", "v" },
			"<Leader>aa",
			"<cmd>CodeCompanionActions<cr>",
			{ noremap = true, silent = true, desc = "Open actions palette" }
		)

		vim.keymap.set(
			{ "n", "v" },
			"<Leader>ac",
			"<cmd>CodeCompanionChat Toggle<cr>",
			{ noremap = true, silent = true, desc = "Toggle chat buffer" }
		)

		vim.keymap.set(
			"v",
			"<Leader>as",
			"<cmd>CodeCompanionChat Add<cr>",
			{ noremap = true, silent = true, desc = "Add selection to chat" }
		)

		vim.keymap.set(
			{ "n", "v" },
			"<Leader>ai",
			"<cmd>CodeCompanion<cr>",
			{ noremap = true, silent = true, desc = "Inline interaction" }
		)

		vim.keymap.set(
			"n",
			"<Leader>al",
			"<cmd>CodeCompanionCLI<cr>",
			{ noremap = true, silent = true, desc = "Open CLI interaction" }
		)

		vim.keymap.set(
			"n",
			"<Leader>am",
			"<cmd>CodeCompanionCmd<cr>",
			{ noremap = true, silent = true, desc = "Generate command" }
		)

		-- 命令行缩写
		-- vim.cmd([[cab cc CodeCompanion]])
	end,
}
