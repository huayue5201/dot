-- https://github.com/huayue5201/buffer-preview.nvim
-- fork of https://github.com/propilideno/buffer-preview.nvim
-- 本地 fork（上游 2026-05 后停更）：
--   滚轮判断修复 / 窗口自适应 / 双图重叠修复 / 异步渲染（不阻塞 UI）
--   缓存按 dpi+源文件失效、按天数与体积自动清理
--   docx/xlsx 等 office 文档、文本侧栏（t/y）、缩放（+/-）、下一页预取
--   :checkhealth buffer-preview 查看依赖
return {
	dir = "~/neovim-plugins/buffer-preview.nvim",
	dependencies = {
		"3rd/image.nvim", -- only needed for image preview (PDF / office documents)
	},
	config = function()
		require("buffer-preview").setup({
			-- "pdftoppm" (default) or "pdftocairo"
			rasterizer = "pdftoppm",
			-- Base rasterization DPI (higher = sharper but slower)
			dpi = 200,
			-- Where rendered page PNGs are cached
			cache_dir = vim.fn.stdpath("cache") .. "/buffer-preview.nvim",
			-- 超过这个天数的缓存目录会在启动后后台清理；false 关闭
			cache_max_age_days = 30,
			-- 缓存总体积上限（MiB），超出后从最旧的开始删；false 关闭
			max_cache_size_mb = 500,
			-- 后台预渲染下一页
			prefetch = true,
			-- `+` / `-` 的缩放倍数（按 dpi * zoom 重新栅格化，不失真）
			zoom_step = 1.25,
			-- SQLite 结果最多渲染多少行，超出会截断并可 :BufferPreviewExport 导出
			sqlite_max_rows = 1000,
			-- 如需自定义键位，覆盖对应项即可；keymaps = false 全部禁用
			-- keymaps = {
			-- 	next_page = { "j", "<Down>" },
			-- 	prev_page = { "k", "<Up>" },
			-- 	first_page = "g",
			-- 	last_page = "G",
			-- 	zoom_in = "+",
			-- 	zoom_out = "-",
			-- 	zoom_reset = "=",
			-- 	page_text = "t",
			-- 	yank_page_text = "y",
			-- 	refresh = { "r", "<C-l>" },
			-- 	close = "q",
			-- },
		})
	end,
}
