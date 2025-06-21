-- https://github.com/dhananjaylatkar/cscope_maps.nvim

return {
	"dhananjaylatkar/cscope_maps.nvim",
	ft = { "c" },
	dependencies = {
		"ludovicchabant/vim-gutentags",
	},
	config = function()
		require("cscope_maps").setup({
			-- 映射相关的默认设置
			disable_maps = false, -- "true" 禁用默认的键映射
			skip_input_prompt = false, -- "true" 不提示输入
			prefix = "<leader>c", -- 触发映射的前缀键

			-- cscope 相关的默认设置
			cscope = {
				-- cscope 数据库文件的位置
				db_file = "./cscope.out", -- 数据库或数据库表
				-- 注意：
				--   当提供多个数据库时，第一个数据库为“主数据库”，其他为“次数据库”
				--   主数据库用于构建和项目根目录定位
				-- cscope 可执行文件
				exec = "cscope", -- 可选值： "cscope" 或 "gtags-cscope"
				-- 选择你喜欢的 picker
				picker = "location", -- 可选值： "quickfix"、"location"、"telescope"、"fzf-lua"、"mini-pick" 或 "snacks"
				picker_opts = {
					window_size = 5, -- 设置为任意正整数
					window_pos = "bottom", -- 可选值： "bottom"、"right"、"left" 或 "top"
				},
				-- "true" 不打开 picker 对于单一结果，直接跳转
				skip_picker_for_single_result = false, -- "false" 或 "true"
				-- 可以使用自定义脚本来构建数据库
				db_build_cmd = { script = "default", args = { "-bqkv" } },
				-- 状态栏指示符，默认为 cscope 可执行文件
				-- statusline_indicator = nil,
				-- 尝试在父目录中查找 db_file
				project_rooter = {
					enable = false, -- "true" 或 "false"
					-- 将当前工作目录切换到 db_file 所在的目录
					change_cwd = false, -- "true" 或 "false"
				},
				-- cstag 相关的默认设置
				tag = {
					-- 将 ":Cstag" 绑定到 "<C-]>"
					keymap = true, -- "true" 或 "false"
					-- ":Cstag" 执行时的操作顺序
					order = { "cs", "tag_picker", "tag" }, -- 可以是这三种操作的任意组合（也可以不包含某些操作）
					-- 在上面操作表中使用的 "tag" 操作命令
					tag_cmd = "tjump",
				},
			},

			-- 栈视图相关的默认设置
			stack_view = {
				tree_hl = true, -- 切换树形结构的高亮显示
			},
		})
	end,
}
