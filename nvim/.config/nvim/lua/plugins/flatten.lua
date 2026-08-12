-- https://github.com/willothy/flatten.nvim

return {
	"willothy/flatten.nvim",
	lazy = false,
	priority = 1001,
	config = function()
		local flatten = require("flatten")

		-- 保存 toggleterm 终端引用的变量
		local saved_terminal = nil

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
					return vim.tbl_contains(argv, "-b")
				end,

				-- 打开文件前：保存当前 toggleterm 终端
				pre_open = function()
					local ok, term = pcall(require, "toggleterm.terminal")
					if ok then
						local termid = term.get_focused_id()
						if termid then
							saved_terminal = term.get(termid)
						end
					end
				end,

				-- 打开文件后：处理终端关闭和 git 文件自动删除
				post_open = function(opts)
					-- 如果是阻塞模式且有保存的终端，关闭它
					if opts.is_blocking and saved_terminal then
						saved_terminal:close()
					else
						-- 非阻塞模式，聚焦到文件窗口
						vim.api.nvim_set_current_win(opts.winnr)
					end

					-- 如果是 git commit/rebase 文件，保存后自动删除 buffer
					if opts.filetype == "gitcommit" or opts.filetype == "gitrebase" then
						vim.api.nvim_create_autocmd("BufWritePost", {
							buffer = opts.bufnr,
							once = true,
							callback = vim.schedule_wrap(function()
								vim.api.nvim_buf_delete(opts.bufnr, {})
							end),
						})
					end
				end,

				-- 阻塞结束后：重新打开之前关闭的终端
				block_end = function()
					vim.schedule(function()
						if saved_terminal then
							saved_terminal:open()
							saved_terminal = nil
						end
					end)
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
