-- https://github.com/dhananjaylatkar/cscope_maps.nvim

return {
	"dhananjaylatkar/cscope_maps.nvim",
	dependencies = {
		"nvim-telescope/telescope.nvim", -- optional [for picker="telescope"]
		"nvim-tree/nvim-web-devicons", -- optional [for devicons in telescope or fzf]
	},
	keys = "<leader>c",
	config = function()
		require("cscope_maps").setup({
			-- maps related defaults
			disable_maps = false, -- "true" disables default keymaps
			skip_input_prompt = false, -- "true" doesn't ask for input
			prefix = "<leader>c", -- prefix to trigger maps

			-- cscope related defaults
			cscope = {
				-- location of cscope db file
				db_file = "./cscope.out", -- DB or table of DBs
				-- NOTE:
				--   when table of DBs is provided -
				--   first DB is "primary" and others are "secondary"
				--   primary DB is used for build and project_rooter
				--   secondary DBs must be built with absolute paths
				--   or paths relative to cwd. Otherwise JUMP will not work.
				-- cscope executable
				exec = "gtags-cscope", -- "cscope" or "gtags-cscope"
				-- choose your fav picker
				picker = "quickfix", -- "telescope", "fzf-lua" or "quickfix"
				-- size of quickfix window
				qf_window_size = 5, -- any positive integer
				-- position of quickfix window
				qf_window_pos = "bottom", -- "bottom", "right", "left" or "top"
				-- "true" does not open picker for single result, just JUMP
				skip_picker_for_single_result = true, -- "false" or "true"
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

		-- 自动构建gtags文件
		local group = vim.api.nvim_create_augroup("CscopeBuild", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", {
			pattern = { "*.c", "*.h" },
			callback = function()
				vim.cmd("Cscope db build")
			end,
			group = group,
		})
	end,
}

--    键图	             描述
-- <prefix>s	  查找光标下令牌的所有引用
-- <prefix>g	  在光标下找到令牌的全局定义
-- <prefix>c	  在光标下找到对函数名称的所有调用
-- <prefix>t	  在光标下找到文本的所有实例
-- <prefix>e	  egrep在光标下搜索单词
-- <prefix>f	  在光标下打开文件名
-- <prefix>i	  查找光标下包含文件名的文件
-- <prefix>d	  查找光标调用下起作用的函数
-- <prefix>a	  找到这个符号被赋值的地方
-- <prefix>b	  构建cscope数据库
-- Ctrl-]	      做:Cstag <cword>
