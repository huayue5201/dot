-- https://github.com/minigian/juan-logs.nvim

return {
	"minigian/juan-logs.nvim",
	build = function(plugin)
		local path = plugin.dir .. "/build.lua"
		if vim.fn.filereadable(path) == 1 then
			dofile(path)
		end
	end,
	-- 如果你的系统有 `cargo`，也可以使用 `build = "cargo build --release"`
	config = function()
		require("juanlog").setup({
			threshold_size = 1024 * 1024 * 100, -- 触发阈值：100MB
			mode = "dynamic", -- 另一种模式名称我忘了，但没什么用，不用担心
			lazy = true, -- 后台索引，防止 Neovim 卡顿
			dynamic_chunk_size = 10000, -- 每次加载的行数
			dynamic_margin = 2000, -- 距离底部多少行时触发滚动加载
			patterns = { "*.log", "*.txt", "*.csv", "*.json" }, -- 匹配的文件模式
			enable_custom_statuscol = true, -- 启用自定义状态列（模拟绝对行号）
			syntax = false, -- 启用原生 Vim 语法高亮（可能会变慢）
		})
	end,
}
