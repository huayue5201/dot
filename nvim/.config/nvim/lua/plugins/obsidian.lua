-- https://github.com/obsidian-nvim/obsidian.nvim

return {
	"obsidian-nvim/obsidian.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim", -- 必需的工具库
	},
	config = function()
		local obsidian = require("obsidian")

		-- 配置 obsidian.nvim
		obsidian.setup({
			-- ⚠️ 重要：将路径替换为你自己的 Obsidian 仓库路径
			workspaces = {
				{
					name = "personal",
					path = "~/rust-project/data_pulse/note", -- 示例路径
				},
				-- 可以添加多个工作区
				-- {
				--   name = "work",
				--   path = "~/Documents/Obsidian/Work",
				-- },
			},

			-- 日常笔记设置
			daily_notes = {
				folder = "Daily Notes", -- 存放每日笔记的文件夹
				date_format = "%Y-%m-%d", -- 日期格式
				default_tags = { "daily" }, -- 默认标签
				-- workdays_only = true, -- 只在工作日创建
			},

			-- 新笔记默认存放位置
			new_notes_location = "current_dir",

			-- 链接风格，wiki 风格与 Obsidian 兼容性最好
			link = {
				style = "wiki",
				format = "shortest",
				auto_update = false,
			},

			-- 附件（图片等）存放位置
			attachments = {
				folder = "attachments",
				img_name_func = function()
					return string.format("Pasted image %s", os.date("%Y%m%d%H%M%S"))
				end,
				img_text_func = function(path)
					return string.format("![%s](%s)", path:stem(), path)
				end,
			},

			-- 完成（补全）设置，适配 blink.cmp
			completion = {
				-- 触发补全的最小字符数
				min_chars = 2,
				-- 是否区分大小写
				match_case = true,
				-- 是否允许在补全时创建新笔记（当匹配不到时）
				create_new = true,
			},

			-- 禁用 legacy 命令，保持命令列表干净
			legacy_commands = false,

			-- ========== 复选框核心配置 ==========
			-- 控制切换顺序和功能
			checkbox = {
				enabled = true, -- 启用复选框功能
				create_new = true, -- 是否在段落中创建新复选框
				order = { " ", "~", "!", ">", "x" }, -- ⭐ 切换顺序，按此循环
			},

			-- 页脚显示笔记信息
			footer = {
				enabled = true,
				format = "{{backlinks}} backlinks  {{properties}} properties  {{words}} words  {{chars}} chars",
				hl_group = "Comment",
				separator = string.rep("-", 80),
			},

			-- 模板设置（如果需要）
			templates = {
				enabled = true,
				folder = nil, -- 默认为仓库根目录下的 "templates" 文件夹
				date_format = "%Y-%m-%d",
				time_format = "%H:%M",
				substitutions = {}, -- 自定义模板变量
			},

			-- 搜索设置
			search = {
				sort_by = "modified",
				sort_reversed = true,
				max_lines = 1000,
			},
		})

		-- ========================================
		-- 键位映射：所有映射以 <leader>ob 为前缀
		-- 假设 <leader> 是空格键，即 <Space>ob...
		-- ========================================
		local map = vim.keymap.set
		local opts = { noremap = true, silent = true }

		-- 1. 核心导航（每日笔记）
		map(
			"n",
			"<leader>obt",
			"<cmd>Obsidian today<CR>",
			vim.tbl_extend("force", opts, { desc = "打开今日笔记" })
		)
		map(
			"n",
			"<leader>oby",
			"<cmd>Obsidian yesterday<CR>",
			vim.tbl_extend("force", opts, { desc = "打开昨日笔记" })
		)
		map(
			"n",
			"<leader>obT",
			"<cmd>Obsidian tomorrow<CR>",
			vim.tbl_extend("force", opts, { desc = "打开明日笔记" })
		)

		-- 2. 笔记切换与搜索
		map(
			"n",
			"<leader>obs",
			"<cmd>Obsidian quick_switch<CR>",
			vim.tbl_extend("force", opts, { desc = "快速切换笔记" })
		)
		map(
			"n",
			"<leader>obf",
			"<cmd>Obsidian search<CR>",
			vim.tbl_extend("force", opts, { desc = "全文搜索笔记" })
		)
		map(
			"n",
			"<leader>obg",
			"<cmd>Obsidian tags<CR>",
			vim.tbl_extend("force", opts, { desc = "查看所有标签" })
		)

		-- 3. 笔记创建与链接
		map("n", "<leader>obn", "<cmd>Obsidian new<CR>", vim.tbl_extend("force", opts, { desc = "创建新笔记" }))
		map(
			"n",
			"<leader>obN",
			"<cmd>Obsidian new_from_template<CR>",
			vim.tbl_extend("force", opts, { desc = "从模板创建新笔记" })
		)
		-- 可视化模式下的链接操作
		map(
			"v",
			"<leader>obl",
			"<cmd>Obsidian link<CR>",
			vim.tbl_extend("force", opts, { desc = "链接选中文本到已有笔记" })
		)
		map(
			"v",
			"<leader>obL",
			"<cmd>Obsidian link_new<CR>",
			vim.tbl_extend("force", opts, { desc = "链接选中文本并创建新笔记" })
		)
		map(
			"v",
			"<leader>obe",
			"<cmd>Obsidian extract_note<CR>",
			vim.tbl_extend("force", opts, { desc = "提取选中文本为新笔记" })
		)

		-- 4. 当前笔记操作
		map(
			"n",
			"<leader>obb",
			"<cmd>Obsidian backlinks<CR>",
			vim.tbl_extend("force", opts, { desc = "查看反向链接" })
		)
		map("n", "<leader>obc", "<cmd>Obsidian toc<CR>", vim.tbl_extend("force", opts, { desc = "查看目录" }))
		map(
			"n",
			"<leader>obr",
			"<cmd>Obsidian rename<CR>",
			vim.tbl_extend("force", opts, { desc = "重命名笔记并更新链接" })
		)

		-- 5. 图片与附件
		map("n", "<leader>obi", "<cmd>Obsidian paste_img<CR>", vim.tbl_extend("force", opts, { desc = "粘贴图片" }))

		-- 6. 工作区切换
		map(
			"n",
			"<leader>obw",
			"<cmd>Obsidian workspace<CR>",
			vim.tbl_extend("force", opts, { desc = "切换工作区" })
		)

		-- 7. 其他实用命令
		map(
			"n",
			"<leader>obd",
			"<cmd>Obsidian dailies<CR>",
			vim.tbl_extend("force", opts, { desc = "查看每日笔记列表" })
		)
		map(
			"n",
			"<leader>obh",
			"<cmd>Obsidian help<CR>",
			vim.tbl_extend("force", opts, { desc = "查看帮助文档" })
		)

		-- 8. 智能动作：在 Obsidian 笔记中，<CR> 默认就是 smart_action
		-- 所以无需额外映射，但如果你想要更明确的绑定：
		-- map("n", "<CR>", function()
		--   if vim.bo.filetype == "markdown" then
		--     require("obsidian").action.smart_action()
		--   else
		--     vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, true, true), "n", false)
		--   end
		-- end, { desc = "Obsidian 智能动作" })

		-- ========================================
		-- 可选：设置 autocmd 来优化体验
		-- ========================================

		-- 保存时自动格式化表格（可选）
		-- vim.api.nvim_create_autocmd("BufWritePre", {
		--   pattern = "*.md",
		--   group = group,
		--   callback = function()
		--     -- 这里可以调用表格格式化函数
		--   end,
		-- })
	end,
}
