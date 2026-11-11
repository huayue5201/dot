-- https://github.com/huayue5201/project-overview.nvim
-- :Project 项目概览；AI / chat 集成放在本配置侧（插件本身零业务依赖）。
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "ProjectOverview" })
end

return {
	dir = "~/neovim-plugins/project-overview.nvim",
	config = function()
		local project = require("project_overview")
		project.setup({
			keys = { open = "<leader>ii", ask = "<leader>ia", chat = "<leader>ic" },
			ask = function(text, tokens)
				local ok, ai = pcall(require, "ask_agent")
				if not ok then
					notify("没有 ask_agent 模块，无法发问", vim.log.levels.WARN)
					return
				end
				local sent, err = pcall(ai.ask, {
					note = ("概览 ~%d tok"):format(tokens),
					extension = { digest = text },
				})
				if not sent then
					notify(tostring(err), vim.log.levels.WARN)
				end
			end,
			chat = function(text, tokens, opts)
				local ok, cc = pcall(require, "codecompanion")
				if not ok then
					notify("没有 codecompanion 插件，改用 :ProjectAsk", vim.log.levels.WARN)
					return
				end
				local adapter = (opts and opts.adapter) or "deepseek"
				local chat_opts = {
					-- auto_submit=false：只把摘要放进去，问题由你在 chat 里写
					auto_submit = false,
					messages = {
						{
							role = "user",
							content = ("（项目概览索引，供后续提问参考；只有结构与统计，不含源码）\n\n<project-overview>\n%s\n</project-overview>"):format(
								text
							),
						},
					},
				}
				if adapter ~= "default" then
					chat_opts.params = { adapter = adapter }
				end
				local sent, err = pcall(cc.chat, chat_opts)
				if not sent then
					notify("打开 codecompanion chat 失败：" .. tostring(err), vim.log.levels.WARN)
					return
				end
				notify(
					("概览已放进 chat（adapter=%s，~%d tok）：接着在里面提问即可"):format(adapter, tokens),
					vim.log.levels.INFO
				)
			end,
		})

		-- 保留原来的短命令，日常肌肉记忆不变
		vim.api.nvim_create_user_command("Project", function(args)
			project.open({ full = args.bang })
		end, { bang = true, force = true, desc = "项目概览（!: 完整版）" })
		vim.api.nvim_create_user_command("ProjectAsk", function()
			project.ask()
		end, { force = true, desc = "带着项目概览问 AI（精简摘要随问题发出）" })
		vim.api.nvim_create_user_command("ProjectChat", function(args)
			project.chat({ adapter = args.args ~= "" and args.args or nil })
		end, {
			nargs = "?",
			force = true,
			desc = "把项目概览摘要放进 codecompanion chat（默认 deepseek，可传 pi）",
			complete = function()
				return { "deepseek", "pi", "default" }
			end,
		})
	end,
}
