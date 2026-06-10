-- https://chat.deepseek.com/a/chat/s/bb9fcf56-699e-456f-9ce5-75bd6993e19b

return {
	-- 自动检测文件缩进风格的插件
	-- 当你打开一个文件时，自动分析其缩进方式（空格或Tab，以及缩进宽度）
	-- 并自动设置 vim 的 shiftwidth、tabstop、expandtab 等选项
	"NMAC427/guess-indent.nvim",

	-- 触发时机：在读取文件之前加载（确保打开文件时就能检测）
	event = "BufReadPre",

	config = function()
		require("guess-indent").setup({

			-- ========== 基础行为配置 ==========

			-- 是否自动检测
			-- true: 每次打开文件自动检测缩进
			-- false: 不自动检测，需要手动执行 :GuessIndent 命令
			auto_cmd = true,

			-- 是否覆盖 .editorconfig 的设置
			-- false: 尊重项目中的 .editorconfig 文件（推荐）
			-- true: 检测结果优先级高于 .editorconfig
			override_editorconfig = false,

			-- ========== 排除配置 ==========
			-- 这些文件类型不进行自动检测
			filetype_exclude = {
				"netrw", -- 内置文件浏览器
				"tutor", -- Vim 教程
				"help", -- 帮助文档
				"dashboard", -- 启动仪表板（如 dashboard-nvim）
				"NvimTree", -- 文件树插件
				"lazy", -- lazy.nvim 插件管理器窗口
				"mason", -- mason.nvim LSP 安装器
				"toggleterm", -- 浮动终端
				"TelescopePrompt", -- Telescope 搜索窗口
				"gitcommit", -- Git 提交信息（通常已有规范）
				"markdown", -- Markdown 文件（缩进不规范，避免误判）
				"txt", -- 纯文本文件
			},

			-- 这些缓冲区类型不进行自动检测
			buftype_exclude = {
				"help", -- 帮助缓冲区
				"nofile", -- 无文件缓冲区（如临时窗口）
				"terminal", -- 终端缓冲区
				"prompt", -- 命令提示符缓冲区
			},

			-- ========== 检测到使用 Tab 时的设置 ==========
			on_tab_options = {
				-- 不使用空格缩进（保持 Tab 字符）
				expandtab = false,
				-- 注意：shiftwidth 会自动设置为检测到的缩进宽度
				-- 例如检测到 Tab 宽度为 4，则 shiftwidth 自动设为 4
			},

			-- ========== 检测到使用空格时的设置 ==========
			on_space_options = {
				-- 使用空格缩进
				expandtab = true,

				-- "detected" 表示使用自动检测到的缩进宽度
				-- 例如检测到缩进是 2 空格，则以下选项都设为 2
				tabstop = "detected", -- Tab 键对应的空格数
				softtabstop = "detected", -- 编辑时按 Tab 插入的空格数
				shiftwidth = "detected", -- 缩进操作（>>、<<）使用的空格数
			},
		})

		-- ========== 可选：添加手动命令查看当前缩进设置 ==========
		-- 使用 :ShowIndent 命令可以查看当前缓冲区的缩进配置
		vim.api.nvim_create_user_command("ShowIndent", function()
			local indent_info = string.format(
				"缩进设置 | expandtab=%s | shiftwidth=%d | tabstop=%d | softtabstop=%d",
				vim.bo.expandtab and "空格" or "Tab",
				vim.bo.shiftwidth,
				vim.bo.tabstop,
				vim.bo.softtabstop
			)
			vim.notify(indent_info, vim.log.levels.INFO, { title = "guess-indent" })
		end, {})
	end,
}
