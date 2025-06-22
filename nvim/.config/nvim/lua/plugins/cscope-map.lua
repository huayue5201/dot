-- https://github.com/dhananjaylatkar/cscope_maps.nvim

return {
	"dhananjaylatkar/cscope_maps.nvim",
	ft = "c",
	dependencies = "ludovicchabant/vim-gutentags",
	config = function()
		require("cscope_maps").setup({
			-- 与映射相关的默认设置
			disable_maps = false, -- "true" 禁用默认的快捷键映射
			skip_input_prompt = false, -- "true" 不提示输入
			prefix = "<leader>c", -- 触发映射的前缀

			-- cscope 相关的默认设置
			cscope = {
				-- cscope 数据库文件的位置
				-- db_file = "./cscope.out",
				-- db_file = "~/.cache/.gutentags",
				-- 注意：
				--   当提供多个数据库时 -
				--   第一个数据库是 "primary"（主数据库），其他是 "secondary"（次数据库）
				--   主数据库用于构建和项目根目录定位
				-- cscope 可执行文件
				exec = "cscope", -- "cscope" 或 "gtags-cscope"
				-- 选择你喜欢的选择器
				picker = "location", -- "quickfix"、"location"、"telescope"、"fzf-lua"、"mini-pick" 或 "snacks"
				picker_opts = {
					window_size = 5, -- 任何正整数
					window_pos = "bottom", -- "bottom"、"right"、"left" 或 "top"
				},
				-- "true" 表示对单一结果不弹出选择器，直接跳转
				skip_picker_for_single_result = false, -- "false" 或 "true"
				-- 可以使用自定义脚本来构建数据库
				-- db_build_cmd = { script = "default", args = { "-Rbq" } },
				-- 状态栏指示符，默认为 cscope 可执行文件
				statusline_indicator = nil,
				-- 尝试在父目录中查找 db_file
				project_rooter = {
					enable = false, -- "true" 或 "false"
					-- 将工作目录更改为数据库文件所在的目录
					change_cwd = false, -- "true" 或 "false"
				},
				-- cstag 相关的默认设置
				tag = {
					-- 将 ":Cstag" 绑定到 "<C-]>"
					keymap = true, -- "true" 或 "false"
					-- ":Cstag" 执行的操作顺序
					order = { "cs", "tag_picker", "tag" }, -- 这三者的任何组合（操作可以排除）
					-- 上述操作表中 "tag" 操作使用的命令
					tag_cmd = "tjump",
				},
			},

			-- 堆栈视图默认设置
			stack_view = {
				tree_hl = true, -- 切换树形结构高亮
			},
		})

		-- 创建一个快捷键映射，触发向下栈视图操作的输入框
		vim.keymap.set("n", "<leader>cj", function()
			vim.ui.input({ prompt = "请输入符号以查看向下栈视图: " }, function(symbol)
				if symbol then
					-- 执行 CsStackView open down 命令
					vim.cmd("CsStackView open down " .. symbol)
				end
			end)
		end, { desc = "打开符号的向下栈视图" })

		-- 创建一个快捷键映射，触发向上栈视图操作的输入框
		vim.keymap.set("n", "<leader>ck", function()
			vim.ui.input({ prompt = "请输入符号以查看向上栈视图: " }, function(symbol)
				if symbol then
					-- 执行 CsStackView open up 命令
					vim.cmd("CsStackView open up " .. symbol)
				end
			end)
		end, { desc = "打开符号的向上栈视图" })
	end,
}
