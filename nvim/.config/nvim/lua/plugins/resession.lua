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

			-- 缓冲区过滤：与 tab_workspace 的「工作区 buffer」口径保持一致
			-- （排除 help/quickfix/终端/面板/无名 buffer），否则会出现
			-- 「会话里存了、恢复后却没人认领」的 buffer。
			buf_filter = function(bufnr)
				return require("feat.tab_workspace.util").is_saved_buf(bufnr)
			end,

			-- 加载会话时显示详细信息
			load_detail = true,

			-- 按修改时间排序（最近修改的排在前面）
			load_order = "modification_time",

			-- 扩展配置
			extensions = {
				quickfix = {}, -- 保存和恢复 quickfix 列表
				tab_workspace = {}, -- 保存/恢复「一 tab 一工作区」的 buffer 归属（lua/resession/extensions/tab_workspace.lua）
				tw_terminal = {}, -- 保存/恢复终端面板与终端侧栏窗口（lua/resession/extensions/tw_terminal.lua）
			},
		})

		-- 快捷键配置：会话属于 tab / 工作区域，统一放在 <leader>ls
		local resession = require("resession")
		vim.keymap.set("n", "<leader>lss", resession.save_tab, { desc = "会话: 保存当前标签" })
		vim.keymap.set("n", "<leader>lst", function()
			require("feat.tab_workspace").save_session()
		end, { desc = "会话: 保存当前会话" })
		vim.keymap.set("n", "<leader>lsl", resession.load, { desc = "会话: 加载" })
		vim.keymap.set("n", "<leader>lsd", resession.delete, { desc = "会话: 删除" })

		-- 载入侧的清洗：resession 没有 load 侧的 buffer filter，而它对每个存下的 buffer
		-- 会做 bufadd + bufload，bufload 一个 term:// 名字会把 shell 真拉起来
		-- （症状：<leader>lsl 加载旧会话时凭空打开一个终端）。
		-- files.load_json_file 是 load 的唯一读入口，在这里洗一遍。
		local files = require("resession.files")
		local load_json_file = files.load_json_file
		files.load_json_file = function(path)
			local data = load_json_file(path)
			if type(data) == "table" then
				pcall(require("feat.tab_workspace.session").strip_terminal_bufs, data)
			end
			return data
		end

		-- tab_workspace 的 post_load 钩子必须在 resession 加载后才能挂（init 阶段 require 不到）
		if not require("feat.tab_workspace").attach_resession() then
			vim.notify("tab_workspace: resession 钩子挂接失败，工作区恢复不可用", vim.log.levels.WARN)
		end

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

		-- 加载完把仍有残留的僵尸 term:// buffer 清掉（旧版本写入 / bufadd 造出的空壳）
		resession.add_hook("post_load", function()
			vim.schedule(function()
				for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
					local name = vim.api.nvim_buf_get_name(bufnr)
					if name:find("^term://") and vim.bo[bufnr].buftype == "" and not vim.b[bufnr].terminal_job_id then
						pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
					end
				end
			end)
		end)
	end,
}
