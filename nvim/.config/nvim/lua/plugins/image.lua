-- https://github.com/3rd/image.nvim

return {
	"3rd/image.nvim",
	event = "VeryLazy",
	config = function()
		require("image").setup({
			-- 后端渲染引擎：kitty（推荐）、ueberzug 或 sixel
			backend = "kitty",
			-- 图像处理器：magick_cli（ImageMagick命令行）或 magick_rock（高性能）
			processor = "magick_cli",

			-- 集成配置（各文件类型中的图像渲染）
			integrations = {
				-- Markdown 文件配置
				markdown = {
					enabled = true, -- 是否启用 Markdown 图像渲染
					clear_in_insert_mode = false, -- 插入模式下是否清除图像（避免干扰输入）
					download_remote_images = true, -- 是否下载并显示远程图像URL
					only_render_image_at_cursor = false, -- 是否仅渲染光标所在的图像
					only_render_image_at_cursor_mode = "popup", -- 光标聚焦模式："popup"（弹窗）或 "inline"（内联）
					floating_windows = false, -- 是否在浮动Markdown窗口中渲染图像
					filetypes = { "markdown", "vimwiki" }, -- 生效的文件类型（可添加Quarto等扩展）
				},
				-- AsciiDoc 文件配置
				asciidoc = {
					enabled = true,
					clear_in_insert_mode = false,
					download_remote_images = true,
					only_render_image_at_cursor = false,
					only_render_image_at_cursor_mode = "popup",
					floating_windows = false,
					filetypes = { "asciidoc", "adoc" },
				},
				-- Neorg 文件配置（结构化笔记）
				neorg = {
					enabled = true,
					filetypes = { "norg" },
				},
				-- reStructuredText 文件配置
				rst = {
					enabled = true,
				},
				-- Typst 文件配置（排版系统）
				typst = {
					enabled = true,
					filetypes = { "typst" },
				},
				-- HTML 文件配置（默认禁用）
				html = {
					enabled = false,
				},
				-- CSS 文件配置（默认禁用）
				css = {
					enabled = false,
				},
			},

			-- 图像尺寸限制（像素单位）
			max_width = nil, -- 最大宽度（像素），nil表示不限制
			max_height = nil, -- 最大高度（像素），nil表示不限制
			max_width_window_percentage = nil, -- 最大宽度占窗口宽度的百分比（覆盖max_width）
			max_height_window_percentage = 50, -- 最大高度占窗口高度的百分比（50%）

			-- 缩放因子（全局图像缩放比例，1.0为原始大小）
			scale_factor = 1.0,

			-- 窗口重叠时自动清除图像（提升性能）
			window_overlap_clear_enabled = false,
			-- 忽略窗口重叠清除的文件类型（弹窗、文档提示、通知等）
			window_overlap_clear_ft_ignore = {
				"cmp_menu", -- 补全菜单
				"cmp_docs", -- 补全文档
				"snacks_notif", -- 零食通知
				"scrollview", -- 滚动视图
				"scrollview_sign", -- 滚动视图标记
			},

			-- 仅在编辑器获得焦点时渲染图像（节省资源）
			editor_only_render_when_focused = false,

			-- 仅在活动Tmux窗口中显示图像（需要关闭visual-activity选项）
			tmux_show_only_in_active_window = false,

			-- 劫持文件模式：将这些图像文件直接打开并渲染（而不是作为文本）
			hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
		})
	end,
}
