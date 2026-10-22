-- https://github.com/stevearc/resession.nvim

return {
	"stevearc/resession.nvim",
	config = function()
		require("resession").setup({
			-- 自动保存配置
			autosave = {
				enabled = true, -- 启用自动保存
				interval = 60, -- 每60秒保存一次
				notify = false, -- 不弹出自动保存通知（避免打扰）
			},

			-- 保存会话的目录（位于 Neovim 的 state 目录下）
			dir = "session",

			-- 保存和恢复的窗口/缓冲区选项
			options = {
				"binary",
				"bufhidden",
				"buflisted",
				"cmdheight",
				"diff",
				"filetype",
				"modifiable",
				"previewwindow",
				"readonly",
				"scrollbind",
				"winfixheight",
				"winfixwidth",
			},

			-- 缓冲区过滤：排除 help、quickfix、终端及无文件名缓冲区
			buf_filter = function(bufnr)
				local buftype = vim.bo[bufnr].buftype
				-- 排除特殊类型缓冲区：nofile / help / quickfix / terminal / prompt 等
				if buftype ~= "" and buftype ~= "acwrite" then
					return false
				end
				-- 排除无文件名（no name）缓冲区
				local name = vim.api.nvim_buf_get_name(bufnr)
				if name == "" then
					return false
				end
				return true
			end,

			-- 加载会话时显示详细信息
			load_detail = true,

			-- 按修改时间排序（最近修改的排在前面）
			load_order = "modification_time",

			-- 扩展配置
			extensions = {
				quickfix = {}, -- 保存和恢复 quickfix 列表
				tab_workspace = {}, -- 保存/恢复「一 tab 一工作区」的 buffer 归属（lua/resession/extensions/tab_workspace.lua）
			},
		})

		-- 快捷键配置：按标签页（tab）保存会话（<leader>o 组 = 格式 / 会话）
		local resession = require("resession")
		vim.keymap.set("n", "<leader>oss", resession.save_tab, { desc = "保存标签会话 (save_tab)" })
		vim.keymap.set("n", "<leader>osl", resession.load, { desc = "加载会话" })
		vim.keymap.set("n", "<leader>osd", resession.delete, { desc = "删除会话" })

		-- tab_workspace 的 post_load 钩子必须在 resession 加载后才能挂（init 阶段 require 不到）
		require("core.tab_workspace").attach_resession()

		-- 会话恢复后：确保 todo2 已 setup，并补渲染当前 tab 的 buffer。
		-- resession 加载期间 eventignore=all 会吞掉 BufRead；tcd 又在 buffer 载入之后才生效，
		-- 所以必须等 post_load（各 tab cwd 已就位）再渲染，否则 store 会绑到错的目录。
		resession.add_hook("post_load", function()
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
