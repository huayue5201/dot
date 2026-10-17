-- https://github.com/404pilo/aicommits.nvim
-- AI 生成 conventional commit message；<leader>hc 触发

return {
	"404pilo/aicommits.nvim",
	event = "VeryLazy",
	config = function()
		require("aicommits").setup({
			-- 走 OpenAI 兼容协议接入 DeepSeek（与 pi agent 同一 API/密钥）
			active_provider = "openai",
			providers = {
				openai = {
					endpoint = "https://api.deepseek.com/v1/chat/completions",
					api_key = vim.env.DEEPSEEK_API_KEY, -- 来自 ~/.env（core.dotenv 已载入）
					model = "deepseek-flash", -- 与 PI_MODEL 一致
					max_length = 72,
					generate = 1, -- DeepSeek 仅支持 n=1（n>1 会 400）
					max_tokens = 4000, -- deepseek-flash 为推理模型，需预留思考 token
					temperature = 0.7,
				},
			},
			integrations = {
				neogit = {
					enabled = true,
					-- 用 <leader>hc（Git 分组）替代 Neogit 的 C，避免冲突
					mappings = { enabled = true, key = "<leader>hc" },
				},
			},
		})

		-- 任意 buffer 也能触发（Neogit 内是 buffer-local 同名映射，动作一致）
		vim.keymap.set("n", "<leader>hc", "<cmd>AICommit<cr>", { desc = "AI: 生成提交信息" })
	end,
}
