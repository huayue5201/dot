-- 本地 fork：https://github.com/huayue5201/neogit-ai-commit.nvim
-- 上游：https://github.com/lululau/neogit-ai-commit.nvim（只读，改动都提交在 fork）
-- 生成动作只发生在 neogit 的 commit 窗口（filetype=gitcommit）里：
--   <C-c><CR> 生成英文、<C-c><C-m> 生成中文、<C-c>m 中文
-- 它直接调用 neogit 内部 API 取 `git diff --cached`，所以没有独立的 git 层。

return {
	"huayue5201/neogit-ai-commit.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		require("neogit-ai-commit").setup({
			-- DeepSeek：OpenAI 兼容端点。插件只认 openai_api_key 这个字段名，
			-- 所以显式把 DEEPSEEK_API_KEY 传进去（~/.env 由 boot.dotenv 读取）。
			openai_api_key = vim.env.DEEPSEEK_API_KEY,
			api_url = "https://api.deepseek.com/v1/chat/completions",
			-- deepseek-flash 是推理模型，短 max_tokens 时输出会被 reasoning 吃光；
			-- deepseek-chat 直出正文，更适合生成提交信息。
			model = vim.env.AI_COMMIT_MODEL or "deepseek-chat",
			max_tokens = 4096,
		})
	end,
}
