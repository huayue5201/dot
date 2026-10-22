-- https://codecompanion.olimorris.dev/
-- 两种用法：
--   1) DeepSeek（HTTP API）：普通聊天 / 内联改写，直连 api.deepseek.com
--   2) pi（ACP Agent）：通过 `pi-acp` 驱动 pi coding agent（pi 自身用 deepseek 模型）

-- 注意：DEEPSEEK_API_KEY 等已由 core.dotenv（init.lua 启动早期）从 ~/.env 载入 vim.env，
-- codecompanion 的 deepseek adapter 直接读 $DEEPSEEK_API_KEY，此处无需重复解析。

-- pi-acp 启动时会去调用 `pi`，确保 pi 的 bin 目录在 PATH 上
local pi_bin = vim.fn.expand("~/.pi/agent/bin")
if vim.env.PATH and not vim.env.PATH:find(pi_bin, 1, true) then
	vim.env.PATH = pi_bin .. ":" .. vim.env.PATH
end

return {
	"olimorris/codecompanion.nvim",
	sem_version = "^19.0.0",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"MeanderingProgrammer/render-markdown.nvim",
	},
	keys = {
		{ "<leader>aa", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "AI: 操作面板" },
		{ "<leader>at", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "AI: 聊天 (DeepSeek)" },
		{ "<leader>an", "<cmd>CodeCompanionChat<cr>", desc = "AI: 新聊天 (DeepSeek)" },
		{ "<leader>ap", "<cmd>CodeCompanionChat adapter=pi<cr>", desc = "AI: pi Agent (ACP)" },
		{ "<leader>ad", "<cmd>CodeCompanionChat Add<cr>", mode = { "n", "v" }, desc = "AI: 加入上下文" },
		{ "<leader>ae", "<cmd>CodeCompanion<cr>", mode = { "n", "v" }, desc = "AI: 内联改写" },
	},
	opts = {
		-- 默认用中文回复（HTTP 适配器会写进 system prompt）
		opts = {
			language = "Chinese",
		},
		-- MCP 服务（stdio）。todo2 走 bridge 模式：子进程继承 $NVIM，
		-- 把工具调用转发回当前这个活着的 nvim 上的 todo2.ai
		mcp = {
			servers = {
				todo2 = {
					cmd = {
						"nvim",
						"--headless",
						"-u",
						"NONE",
						"-l",
						vim.fn.expand("~/neovim-plugins/todo2/mcp/todo2-mcp.lua"),
					},
				},
			},
			opts = {
				-- 打开 chat 时自动启动并把工具挂上（否则用 /mcp 手动起）
				default_servers = { "todo2" },
			},
		},
		adapters = {
			-- 直连 DeepSeek API（模型：deepseek-flash / deepseek-v4-pro）
			http = {
				deepseek = function()
					return require("codecompanion.adapters").extend("deepseek", {
						schema = {
							model = { default = "deepseek-flash" },
						},
					})
				end,
			},
			-- pi coding agent，经 ACP（pi-acp 桥接 pi --mode rpc）
			acp = {
				pi = function()
					return {
						name = "pi",
						formatted_name = "pi (ACP)",
						type = "acp",
						roles = { llm = "assistant", user = "user" },
						opts = { vision = true },
						commands = {
							default = { "pi-acp" },
						},
						defaults = {
							-- pi-acp 的 zod schema 要求 mcpServers 必须是数组（不能缺省），
							-- 否则 session/new 报 -32602 Invalid params
							mcpServers = {},
							timeout = 30000, -- 30s
						},
						parameters = {
							protocolVersion = 1,
							clientCapabilities = {
								fs = { readTextFile = true, writeTextFile = true },
							},
							clientInfo = {
								name = "CodeCompanion.nvim",
								version = "1.0.0",
							},
						},
						handlers = {
							setup = function()
								return true
							end,
							form_messages = function(self, messages, capabilities)
								return require("codecompanion.adapters.acp.helpers").form_messages(
									self,
									messages,
									capabilities
								)
							end,
							on_exit = function() end,
						},
					}
				end,
			},
		},
		interactions = {
			chat = { adapter = "deepseek" },
			inline = { adapter = "deepseek" },
		},
	},
}
