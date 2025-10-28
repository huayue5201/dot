-- https://github.com/igorlfs/nvim-dap-view?tab=readme-ov-file#expanding-variables

return {
	"igorlfs/nvim-dap-view",
	lazy = true,
	config = function()
		-- 设置自定义高亮颜色
		vim.api.nvim_set_hl(0, "ViewBreakpoints", { fg = "#FF3030" }) -- 红色
		vim.api.nvim_set_hl(0, "ViewScopes", { fg = "#FFD700" }) -- 金色
		vim.api.nvim_set_hl(0, "ViewExceptions", { fg = "#20B2AA" }) -- 海蓝色
		vim.api.nvim_set_hl(0, "ViewWatch", { fg = "#8B7E66", bg = nil }) -- 橙色
		vim.api.nvim_set_hl(0, "ViewThreads", { fg = "#8B4789" }) -- 紫红色
		vim.api.nvim_set_hl(0, "ViewREPL", { fg = "#228B22" }) -- 绿色
		vim.api.nvim_set_hl(0, "ViewConsole", { fg = "#FF7F00" }) -- 淡紫色
	end,
}
