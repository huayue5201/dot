-- https://codecompanion.olimorris.dev/
-- 两种用法：
--   1) DeepSeek（HTTP API）：普通聊天 / 内联改写，直连 api.deepseek.com
--   2) pi（ACP Agent）：通过 `pi-acp` 驱动 pi coding agent（pi 自身用 deepseek 模型）

---从 ~/.env 读取某个 KEY（该文件未自动 export 到环境，这里手动注入）
---@param name string
---@return string|nil
local function env_from_file(name)
  local ok, value = pcall(function()
    local file = io.open(vim.fn.expand("~/.env"), "r")
    if not file then
      return nil
    end
    local content = file:read("*a")
    file:close()
    -- 匹配： export NAME=... / NAME=...（可带引号）
    return content:match("^%s*export%s+" .. name .. "%s*=%s*\"?([^\"\r\n]+)\"?")
      or content:match("^%s*" .. name .. "%s*=%s*\"?([^\"\r\n]+)\"?")
  end)
  return ok and value or nil
end

-- DeepSeek key 补进 nvim 环境（codecompanion 的 deepseek adapter 读 $DEEPSEEK_API_KEY）
vim.env.DEEPSEEK_API_KEY = vim.env.DEEPSEEK_API_KEY or env_from_file("DEEPSEEK_API_KEY")

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
	cmd = {
		"CodeCompanion",
		"CodeCompanionChat",
		"CodeCompanionActions",
		"CodeCompanionCmd",
		"CodeCompanionCLI",
		"CodeCompanionCodeReview",
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
								return require("codecompanion.adapters.acp.helpers").form_messages(self, messages, capabilities)
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
