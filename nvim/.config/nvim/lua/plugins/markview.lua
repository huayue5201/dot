-- https://github.com/OXY2DEV/markview.nvim
--
-- Markdown / HTML / LaTeX / Typst / YAML 的「原地渲染」预览（extmarks 隐藏标记 + 高亮，
-- 不是浏览器预览）。支持 hybrid 编辑（光标所在行显示源码）和 splitview（左右对照）。
--
-- 依赖：Neovim >= 0.10.3；markdown / markdown_inline / html / comment 解析器已装
-- （lua/plugins/treesitter.lua 的 ensure_installed），latex / typst 是可选的，用到再 TSInstall。
--
-- 注意：插件自己就是「按 FileType 懒渲染」，官方明确说不要再用 lazy 包一层
-- （只会让预览更慢）。这里保持 eager setup，渲染发生在 md 类 buffer 打开时。
-- 它和 obsidian.nvim（conceallevel=2）、mdkite（浏览器预览）、markmap 互不冲突：
-- 一个改 buffer 内显示，一个开外部窗口/浏览器。
--
-- 渲染范围：markdown/typst/asciidoc 等普通文件照旧；codecompanion 的 chat 浮窗强制渲染；
-- todo2 的 *.todo.md 强制不渲染（见文件内 autocmd 的说明）。

return {
	"OXY2DEV/markview.nvim",
	config = function()
		require("markview").setup({
			preview = {
				-- 已装 nvim-web-devicons，用它出图标（可选 "mini" / "internal"）
				icon_provider = "devicons",

				-- 逐 buffer 决定是否渲染（返回值覆盖 filetypes / ignore_buftypes）：
				--   true = 强制渲染；nil = 交回默认规则（filetype 在列表里 且 buftype 不被忽略）
				-- 注意：**不能**用返回 false 来排除 buffer —— 上游 spec.to_static 写的是
				-- `return ok and res or nil`，false 会被折成 nil，等于没写（v29.0.0）。
				-- 排除 todo2 的 *.todo.md 只能用下面那个 autocmd + buffer 状态。
				condition = function(buf)
					-- codecompanion 的 chat 窗口是 buftype=nofile 的浮窗，默认会被 ignore_buftypes
					-- 挡掉；它的 filetype 已经通过 vim.treesitter.language.register 指向 markdown
					-- 解析器（codecompanion/plugin/codecompanion.lua），所以能正常渲染。
					if vim.bo[buf].filetype == "codecompanion" then
						return true
					end

					return nil
				end,
			},
		})

		-- todo2 的任务文件（~/.todo-files/<项目>/*.todo.md）由 todo2 自己用 conceal +
		-- 虚拟行渲染，markview 再叠一层会两套 extmark 打架（而且 gx 会被改成 Markview open）。
		--
		-- 做法：在 markview attach 之前就把该 buffer 标成「已禁用」，它 attach 时会自己走
		-- clear + reset_query 分支，不画任何东西；再补一刀 disable 兜住已经 attach 的情况。
		local function is_todo2(buf)
			local name = vim.api.nvim_buf_get_name(buf)
			return name:find("/.todo-files/", 1, true) ~= nil or name:match("%.todo%.md$") ~= nil
		end

		local function disable_todo2(buf)
			if not is_todo2(buf) then
				return
			end

			local mk_state = require("markview.state")
			mk_state.set_buffer_state(buf, { enable = false })
			if mk_state.buf_attached(buf) then
				require("markview.actions").disable(buf)
				-- attach 时 markview 会把 gx 改成自己的链接打开器，这里擦掉
				pcall(vim.api.nvim_buf_del_keymap, buf, "n", "gx")
			end

			-- markview 的 disable 会把窗口的 conceallevel 拉回 0，而 todo2 靠 2 隐藏标记；
			-- 交回 todo2 自己那套窗口局部选项（不归它管就手动恢复同值）。
			for _, win in ipairs(vim.fn.win_findbuf(buf)) do
				if not pcall(vim.api.nvim_set_option_value, "conceallevel", 2, { scope = "local", win = win }) then
					break
				end
				vim.api.nvim_set_option_value("concealcursor", "nvic", { scope = "local", win = win })
			end
		end

		vim.api.nvim_create_autocmd({ "BufAdd", "BufNewFile", "BufReadPost", "BufWinEnter", "FileType" }, {
			group = vim.api.nvim_create_augroup("user_markview_skip_todo2", { clear = true }),
			callback = function(args)
				local buf = args.buf
				if not is_todo2(buf) then
					return
				end
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(buf) then
						disable_todo2(buf)
					end
				end)
			end,
		})

		-- codecompanion 的 chat buffer 是「先建 nofile buffer、开完浮窗才设 filetype」，
		-- markview 只在 BufAdd/BufEnter/BufWinEnter 上判断，那时候 ft 还是空的，之后就
		-- 不会重试了。所以自己在 FileType 上补一刀。
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("user_markview_codecompanion", { clear = true }),
			pattern = "codecompanion",
			callback = function(args)
				local buf = args.buf
				vim.schedule(function()
					if not vim.api.nvim_buf_is_valid(buf) then
						return
					end
					local mk_state = require("markview.state")
					local actions = require("markview.actions")
					mk_state.set_buffer_state(buf, { enable = true })
					if mk_state.buf_attached(buf) then
						actions.enable(buf)
					else
						actions.attach(buf)
					end
				end)
			end,
		})

		-- <leader>z = 工具分组（zm 已被 mdkite 的浏览器预览占用）
		-- `Markview Toggle` 会遍历所有 attached buffer 逐个 toggle，会把 todo2 任务文件
		-- 重新打开渲染，所以开关后再把它们压回去。
		vim.keymap.set("n", "<leader>zM", function()
			vim.cmd("Markview Toggle")
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_loaded(buf) then
					disable_todo2(buf)
				end
			end
		end, { silent = true, desc = "Markview: 切换原地渲染（全局）" })
		vim.keymap.set(
			"n",
			"<leader>zV",
			"<cmd>Markview splitToggle<cr>",
			{ silent = true, desc = "Markview: 切换 splitview 对照" }
		)
	end,
}
