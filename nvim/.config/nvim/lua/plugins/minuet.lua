-- https://github.com/milanglacier/minuet-ai.nvim
-- AI 行内补全（ghost text / virtual text），走 DeepSeek FIM 接口
-- （https://api.deepseek.com/beta/completions，按 token 计费，延迟低）。
-- 与 blink.cmp 的关系：主用 virtualtext 前端做行内建议；
-- blink 侧只注册一个 minuet 源，用 <A-y> 手动拉取（见 blink.lua），
-- 不放进 default sources，避免每次输入都打一次 LLM 请求造成费用/延迟。
-- api_key 由 core.dotenv 从 ~/.env 载入的 DEEPSEEK_API_KEY 提供。

return {
	"milanglacier/minuet-ai.nvim",
	-- 全 eager 加载：minuet 与 blink.cmp 都在启动时就绪，require("minuet.blink")
	-- 不会早于插件加载。
	config = function()
		require("minuet").setup({
			provider = "openai_fim_compatible",
			-- FIM 模型每次请求就是一条候选，本地/云端都建议 1
			n_completions = 1,
			-- 流式请求：超时后返回已生成的部分，响应更快
			request_timeout = 2.5,
			throttle = 1000, -- 两次请求最小间隔（ms）
			debounce = 400, -- 停止输入多少 ms 后请求
			notify = "warn",
			provider_options = {
				openai_fim_compatible = {
					api_key = "DEEPSEEK_API_KEY",
					name = "DeepSeek",
					end_point = "https://api.deepseek.com/beta/completions",
					-- 实测 deepseek 会把别名解析到 deepseek-flash
					model = "deepseek-flash",
					optional = {
						max_tokens = 256,
						top_p = 0.9,
					},
				},
			},
			virtualtext = {
				auto_trigger_ft = {
					"lua",
					"python",
					"rust",
					"go",
					"c",
					"cpp",
					"cuda",
					"java",
					"kotlin",
					"swift",
					"zig",
					"javascript",
					"typescript",
					"javascriptreact",
					"typescriptreact",
					"vue",
					"svelte",
					"html",
					"css",
					"scss",
					"bash",
					"sh",
					"zsh",
					"vim",
					"json",
					"jsonc",
					"yaml",
					"toml",
					"sql",
					"markdown",
					"tex",
					"nix",
					"haskell",
					"ruby",
					"php",
					"cs",
				},
				keymap = {
					accept = "<A-a>", -- 接受整个建议
					accept_line = "<A-l>", -- 只接受一行
					accept_n_lines = "<A-n>", -- 接受 n 行（先提示输入数字）
					next = "<A-]>", -- 下一个候选 / 手动触发
					prev = "<A-[>", -- 上一个候选
					dismiss = "<A-d>",
				},
				-- 补全菜单（blink）展开时不显示 ghost text，避免两层提示重叠
				show_on_completion_menu = false,
			},
		})
	end,
}
