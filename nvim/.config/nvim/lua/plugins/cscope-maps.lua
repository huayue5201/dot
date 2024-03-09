-- https://github.com/dhananjaylatkar/cscope_maps.nvim

return {
	"dhananjaylatkar/cscope_maps.nvim",
	-- https://bolt80.com/gutentags/
	dependencies = "ludovicchabant/vim-gutentags",
	ft = { "c", "asm" },
	init = function()
		-- 设置 Gutentags 模块，这是必需的，其他配置是可选的
		vim.g.gutentags_modules = { "cscope_maps" }
		-- 启用 Gutentags 构建倒排索引映射
		vim.g.gutentags_cscope_build_inverted_index_maps = 1
		-- 指定 Gutentags 缓存目录
		vim.g.gutentags_cache_dir = vim.fn.expand("~/.cache/.gutentags")
		-- 设置 Gutentags 生成文件列表的命令，这里使用 fd 工具过滤出 C 和 H 文件
		vim.g.gutentags_file_list_command = "fd -e c -e h"
		-- 启用 Gutentags 跟踪模式（可选）
		-- vim.g.gutentags_trace = 1
	end,
	config = function()
		require("cscope_maps").setup({
			-- maps related defaults
			disable_maps = false, -- "true" disables default keymaps
			skip_input_prompt = false, -- "true" doesn't ask for input
			prefix = "<leader>c", -- prefix to trigger maps

			-- cscope related defaults
			cscope = {
				-- location of cscope db file
				db_file = "./cscope.out",
				-- cscope executable
				exec = "gtags-cscope", -- "cscope" or "gtags-cscope"
				-- choose your fav picker
				picker = "quickfix", -- "telescope", "fzf-lua" or "quickfix"
				-- size of quickfix window
				qf_window_size = 5, -- any positive integer
				-- position of quickfix window
				qf_window_pos = "bottom", -- "bottom", "right", "left" or "top"
				-- "true" does not open picker for single result, just JUMP
				skip_picker_for_single_result = false, -- "false" or "true"
				-- these args are directly passed to "cscope -f <db_file> <args>"
				db_build_cmd_args = { "-bqkv" },
				-- statusline indicator, default is cscope executable
				statusline_indicator = nil,
				-- try to locate db_file in parent dir(s)
				project_rooter = {
					enable = false, -- "true" or "false"
					-- change cwd to where db_file is located
					change_cwd = false, -- "true" or "false"
				},
			},
		})
	end,
}
