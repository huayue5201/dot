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

			-- 缓冲区过滤：排除 help、quickfix 等特殊缓冲区
			buf_filter = function(bufnr)
				-- 排除无文件名的缓冲区、help 缓冲区等
				local buftype = vim.bo[bufnr].buftype
				if buftype == "nofile" or buftype == "help" or buftype == "quickfix" then
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
			},
		})

		-- 快捷键配置（使用 <leader>os 作为前缀）
		local opts = { noremap = true, silent = true }

		-- 保存当前会话
		vim.keymap.set("n", "<leader>oss", function()
			local name = vim.fn.input("Session name: ")
			if name ~= "" then
				require("resession").save(name)
			end
		end, { desc = "Save session" })

		-- 快速保存（使用当前目录名作为会话名）
		vim.keymap.set("n", "<leader>osq", function()
			local cwd = vim.fn.getcwd()
			local name = vim.fn.fnamemodify(cwd, ":t")
			require("resession").save(name, { notify = true })
		end, { desc = "Quick save session (using folder name)" })

		-- 加载会话（交互式选择）
		vim.keymap.set("n", "<leader>osl", function()
			local sessions = require("resession").list()
			if next(sessions) == nil then
				vim.notify("No sessions found", vim.log.levels.WARN)
				return
			end
			vim.ui.select(sessions, {
				prompt = "Select session to load:",
				format_item = function(item)
					return item
				end,
			}, function(choice)
				if choice then
					require("resession").load(choice)
				end
			end)
		end, { desc = "Load session" })

		-- 删除会话
		vim.keymap.set("n", "<leader>osd", function()
			local sessions = require("resession").list()
			if next(sessions) == nil then
				vim.notify("No sessions found", vim.log.levels.WARN)
				return
			end
			vim.ui.select(sessions, {
				prompt = "Select session to delete:",
				format_item = function(item)
					return item
				end,
			}, function(choice)
				if choice then
					require("resession").delete(choice)
				end
			end)
		end, { desc = "Delete session" })

		-- 保存当前标签页为会话
		vim.keymap.set("n", "<leader>ost", function()
			local name = vim.fn.input("Tab session name: ")
			if name ~= "" then
				require("resession").save_tab(name)
			end
		end, { desc = "Save tab session" })

		-- 查看当前会话
		vim.keymap.set("n", "<leader>osi", function()
			local current = require("resession").get_current()
			if current then
				vim.notify("Current session: " .. current, vim.log.levels.INFO)
			else
				vim.notify("No active session", vim.log.levels.INFO)
			end
		end, { desc = "Show current session" })

		-- 脱离当前会话（停止自动保存）
		vim.keymap.set("n", "<leader>osx", function()
			require("resession").detach()
			vim.notify("Detached from session", vim.log.levels.INFO)
		end, { desc = "Detach from session" })

		-- 手动保存当前会话（不弹出提示，使用当前会话名）
		vim.keymap.set("n", "<leader>osw", function()
			local current = require("resession").get_current()
			if current then
				require("resession").save(current, { notify = true })
			else
				vim.notify("No active session, use <leader>oss to save a new one", vim.log.levels.WARN)
			end
		end, { desc = "Save current session" })
	end,
}
