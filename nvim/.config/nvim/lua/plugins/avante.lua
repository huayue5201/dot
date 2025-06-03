-- https://github.com/yetone/avante.nvim

return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	version = false, -- Never set this value to "*"! Never!
	-- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
	build = "make",
	-- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		--- The below dependencies are optional,
		-- "zbirenbaum/copilot.lua", -- for providers='copilot'
		"MeanderingProgrammer/render-markdown.nvim",
	},
	config = function()
		require("avante").setup({
			provider = "ollama",
			providers = {
				ollama = {
					model = "gemma3",
					endpoint = "http://127.0.0.1:11434",
					timeout = 30000, -- Timeout in milliseconds
					extra_request_body = {
						options = {
							temperature = 0.75,
							num_ctx = 20480,
							keep_alive = "5m",
						},
					},
				},
			},
			cursor_applying_provider = "gemma3",
			behaviour = {
				--- ... existing behaviours
				enable_cursor_planning_mode = true, -- enable cursor planning mode!
			},
			-- provider = "copilot",
			-- openai = {
			-- 	endpoint = "https://api.openai.com/v1",
			-- 	model = "gpt-4o", -- your desired model (or use gpt-4o, etc.)
			-- 	timeout = 30000, -- Timeout in milliseconds, increase this for reasoning models
			-- 	temperature = 0,
			-- 	max_completion_tokens = 8192, -- Increase this to include reasoning tokens (for reasoning models)
			-- 	--reasoning_effort = "medium", -- low|medium|high, only used for reasoning models
			-- },
			rag_service = {
				enabled = false, -- 启用 RAG 服务
				host_mount = os.getenv("HOME"), -- RAG 服务的主机挂载路径
				provider = "openai", -- 用于 RAG 服务的提供者（例如 openai 或 ollama）
				llm_model = "", -- 用于 RAG 服务的 LLM 模型
				embed_model = "", -- 用于 RAG 服务的嵌入模型
				endpoint = "https://api.openai.com/v1", -- RAG 服务的 API 端点
			},
			web_search_engine = {
				provider = "tavily", -- tavily, serpapi, searchapi, google, kagi, brave 或 searxng
				proxy = nil, -- proxy support, e.g., http://127.0.0.1:7890
			},
			windows = {
				---@type "right" | "left" | "top" | "bottom"
				position = "right", -- 侧边栏的位置
				wrap = true, -- 类似于 vim.o.wrap
				width = 38, -- 默认基于可用宽度的百分比
				sidebar_header = {
					enabled = true, -- true, false 启用/禁用标题
					align = "center", -- left, center, right 用于标题
					rounded = true,
				},
				input = {
					prefix = "> ",
					height = 8, -- 垂直布局中输入窗口的高度
				},
				edit = {
					border = "rounded",
					start_insert = true, -- 打开编辑窗口时开始插入模式
				},
				ask = {
					floating = false, -- 在浮动窗口中打开 'AvanteAsk' 提示
					start_insert = true, -- 打开询问窗口时开始插入模式
					border = "shadow",
					---@type "ours" | "theirs"
					focus_on_apply = "ours", -- 应用后聚焦的差异
				},
			},
		})
	end,
}
