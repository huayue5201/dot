-- https://github.com/stevearc/resession.nvim
--
-- 所有 resession 的配置/内部适配都收在 feat/tab_workspace/store.lua，
-- 这里只保留插件加载时机与用户键位。
return {
	"stevearc/resession.nvim",
	config = function()
		require("feat.tab_workspace.store").setup()
		local store = require("feat.tab_workspace.store")

		-- 快捷键配置：会话属于 tab / 工作区域，统一放在 <leader>ls
		vim.keymap.set("n", "<leader>lss", function()
			store.save_tab()
		end, { desc = "Session: save current tab" })
		vim.keymap.set("n", "<leader>lst", function()
			require("feat.tab_workspace").save_session()
		end, { desc = "Session: save current session" })
		-- 删除统一走 tab_workspace.delete_session：带确认、显示根目录、跳过当前会话
		vim.keymap.set("n", "<leader>lsd", function()
			require("feat.tab_workspace").delete_session()
		end, { desc = "Session: delete saved session" })

		-- 带归属校验的 autosave（定时器 + VimLeavePre）
		require("feat.tab_workspace.session_guard").setup_autosave({ interval = 60, notify = false })

		-- tab_workspace 的 post_load 钩子必须在 resession 加载后才能挂（init 阶段 require 不到）
		if not require("feat.tab_workspace").attach_resession() then
			vim.notify(
				"tab_workspace: failed to attach resession hooks; workspace restore unavailable",
				vim.log.levels.WARN
			)
		end

		-- 会话恢复后：确保 todo2 已 setup，并补渲染当前 tab 的 buffer。
		-- resession 加载期间 eventignore=all 会吞掉 BufRead；tcd 又在 buffer 载入之后才生效，
		-- 所以必须等 post_load（各 tab cwd 已就位）再渲染，否则 store 会绑到错的目录。
		store.on_post_load(function()
			vim.schedule(function()
				local ok, todo2 = pcall(require, "todo2")
				if not ok then
					return
				end
				if not todo2.is_setup() then
					pcall(todo2.setup, vim.g.todo2_config or {})
				end
				local ok_render, autocmds = pcall(require, "todo2.autocmds")
				if not ok_render then
					return
				end
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					local buf = vim.api.nvim_win_get_buf(win)
					if not vim.b[buf].todo2_rendered and vim.bo[buf].buftype == "" then
						pcall(autocmds.render_buffer, buf)
					end
				end
			end)
		end)
	end,
}
