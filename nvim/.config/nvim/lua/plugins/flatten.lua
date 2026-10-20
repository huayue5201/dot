-- https://github.com/willothy/flatten.nvim

return {
	"willothy/flatten.nvim",
	lazy = false,
	priority = 1001,
	config = function()
		local flatten = require("flatten")


		flatten.setup({
			-- ========== 窗口设置 ==========
			window = {
				-- 在交替窗口（上次使用的窗口）中打开
				open = "alternate",
				-- diff 模式在标签页中垂直分屏
				diff = "tab_vsplit",
				-- 焦点给第一个打开的文件
				focus = "first",
			},

			-- ========== 阻塞设置 ==========
			-- 这些文件类型会阻塞访客实例，直到编辑完成
			block_for = {
				gitcommit = true,
				gitrebase = true,
			},

			-- 无参数时不嵌套
			nest_if_no_args = false,
			-- 即使有命令也不嵌套（通常保持 false）
			nest_if_cmds = false,
			-- 禁用命令透传（通常保持 false）
			disable_cmd_passthrough = false,

			-- ========== 终端集成 ==========
			integrations = {
				kitty = false, -- 如果你用 Kitty，改为 true
				wezterm = false, -- 如果你用 WezTerm，改为 true
			},

			-- ========== 钩子函数 ==========
			hooks = {
				-- 自定义阻塞条件：命令行包含 -b 参数时强制阻塞
				should_block = function(argv)
					return vim.list_contains(argv, "-b")
				end,

				-- 打开文件后：git 文件自动删除
				post_open = function(opts)
					-- 非阻塞模式，聚焦到文件窗口
					if not opts.is_blocking then
						vim.api.nvim_set_current_win(opts.winnr)
					end

					-- 如果是 git commit/rebase 文件，保存后自动删除 buffer
					if opts.filetype == "gitcommit" or opts.filetype == "gitrebase" then
						vim.api.nvim_create_autocmd("BufWritePost", {
							buffer = opts.bufnr,
							once = true,
							callback = function()
								vim.schedule(function()
									vim.api.nvim_buf_delete(opts.bufnr, {})
								end)
							end,
						})
					end
				end,

				-- 无文件时的行为
				no_files = function(opts)
					-- 默认行为：不嵌套，正常打开空 Neovim
					return { nest = false, block = false }
				end,
			},
		})
	end,
}
