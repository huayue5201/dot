-- https://github.com/ludovicchabant/vim-gutentags

return {
	"ludovicchabant/vim-gutentags",
	init = function()
		vim.g.gutentags_modules = { "cscope_maps" } -- This is required. Other config is optional
		-- 检查是否有 'ctags' 命令
		if vim.fn.executable("ctags") == 1 then
			table.insert(vim.g.gutentags_modules, "ctags")
		end

		-- 检查是否有 'gtags-cscope' 和 'gtags' 命令
		if vim.fn.executable("gtags-cscope") == 1 and vim.fn.executable("gtags") == 1 then
			table.insert(vim.g.gutentags_modules, "gtags_cscope")
		end
		vim.g.gutentags_cscope_build_inverted_index_maps = 1
		vim.g.gutentags_cache_dir = vim.fn.expand("~/code/.gutentags")
		vim.g.gutentags_file_list_command = "fd -e c -e h"
		-- vim.g.gutentags_trace = 1
	end,
}
