-- https://github.com/MagicDuck/grug-far.nvim

return {
	"MagicDuck/grug-far.nvim",
	event = "VeryLazy",
	config = function()
		----------------------------------------------------------------------
		-- 基础配置
		----------------------------------------------------------------------
		require("grug-far").setup({
			helpLine = { enabled = false },
			showInputsTopPadding = false,
			showInputsBottomPadding = false,
		})

		----------------------------------------------------------------------
		-- 快捷键：打开 grug-far（不同模式）
		----------------------------------------------------------------------

		-- 使用光标下的单词作为搜索内容
		vim.keymap.set("n", "<leader>gw", function()
			require("grug-far").open({
				prefills = { search = vim.fn.expand("<cword>") },
			})
		end, { desc = "grug-far：使用光标下的单词进行搜索" })

		-- 使用 AST 引擎
		vim.keymap.set("n", "<leader>ga", function()
			require("grug-far").open({ engine = "astgrep" })
		end, { desc = "grug-far：使用 AST 引擎进行搜索" })

		-- 以临时缓冲区打开（关闭后删除）
		vim.keymap.set("n", "<leader>gt", function()
			require("grug-far").open({ transient = true })
		end, { desc = "grug-far：以临时缓冲区打开（关闭后删除）" })

		-- 切换 grug-far 实例可见性
		vim.keymap.set("n", "<leader>gf", function()
			require("grug-far").toggle_instance({
				instanceName = "far",
				staticTitle = "Find and Replace",
			})
		end, { desc = "grug-far：切换实例可见性" })

		-- 限制搜索范围为当前文件
		vim.keymap.set("n", "<leader>gr", function()
			require("grug-far").open({
				prefills = { paths = vim.fn.expand("%") },
			})
		end, { desc = "grug-far：仅搜索当前文件" })

		-- 范围内搜索（自动检测可视选择类型）
		vim.keymap.set({ "n", "x" }, "<leader>gi", function()
			require("grug-far").open({ visualSelectionUsage = "auto-detect" })
		end, { desc = "grug-far: Search within range" })

		-- 使用上次搜索寄存器（@/）的值，或可视选择内容
		vim.keymap.set({ "n", "x" }, "<leader>gs", function()
			local search = vim.fn.getreg("/")
			-- 如果是单词搜索（如按 * 键），用 \b 包围
			if search and vim.startswith(search, "\\<") and vim.endswith(search, "\\>") then
				search = "\\b" .. search:sub(3, -3) .. "\\b"
			elseif search and vim.startswith(search, "\\V") then
				search = search:sub(3)
			end
			local inst = require("grug-far").open({
				prefills = {
					search = search,
				},
			})
			inst:when_ready(function()
				inst:goto_input("replacement")
			end)
		end, { desc = "grug-far: Search using @/ register value or visual selection" })

		----------------------------------------------------------------------
		-- FileType = grug-far 时的 buffer 内键位
		----------------------------------------------------------------------
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("grug-far-keymap", { clear = true }),
			pattern = "grug-far",
			callback = function()
				-- 跳回搜索输入框（按左箭头）
				vim.keymap.set("n", "<left>", function()
					require("grug-far").get_instance(0):goto_first_input()
				end, { buffer = true, desc = "grug-far：跳回搜索输入框" })

				-- 切换 --fixed-strings 标志
				vim.keymap.set("n", "<localleader>s", function()
					local state = unpack(require("grug-far").get_instance(0):toggle_flags({ "--fixed-strings" }))
					vim.notify("grug-far: toggled --fixed-strings " .. (state and "ON" or "OFF"))
				end, { buffer = true, desc = "grug-far：切换固定字符串模式" })

				----------------------------------------------------------------------
				-- 核心操作键位（补全，使用 <leader> 前缀保持风格统一）
				----------------------------------------------------------------------

				-- 执行替换
				vim.keymap.set("n", "<leader>r", function()
					require("grug-far").get_instance(0):replace()
				end, { buffer = true, desc = "grug-far：执行替换" })

				-- 同步当前行
				vim.keymap.set("n", "<leader>sl", function()
					require("grug-far").get_instance(0):sync_line()
				end, { buffer = true, desc = "grug-far：同步当前行" })

				-- 同步全部
				vim.keymap.set("n", "<leader>sa", function()
					require("grug-far").get_instance(0):sync_all()
				end, { buffer = true, desc = "grug-far：同步全部" })

				-- 应用下一个（同步当前行并从结果中删除）
				vim.keymap.set("n", "<leader>an", function()
					require("grug-far").get_instance(0):apply_next()
				end, { buffer = true, desc = "grug-far：应用下一个" })

				-- 应用上一个
				vim.keymap.set("n", "<leader>ap", function()
					require("grug-far").get_instance(0):apply_prev()
				end, { buffer = true, desc = "grug-far：应用上一个" })

				-- 打开历史
				vim.keymap.set("n", "<leader>ho", function()
					require("grug-far").get_instance(0):history_open()
				end, { buffer = true, desc = "grug-far：打开历史" })

				-- 添加到历史
				vim.keymap.set("n", "<leader>ha", function()
					require("grug-far").get_instance(0):history_add()
				end, { buffer = true, desc = "grug-far：添加到历史" })

				-- 切换搜索引擎
				vim.keymap.set("n", "<leader>e", function()
					require("grug-far").get_instance(0):swap_engine()
				end, { buffer = true, desc = "grug-far：切换搜索引擎" })

				-- 中止操作
				vim.keymap.set("n", "<leader>x", function()
					require("grug-far").get_instance(0):abort()
				end, { buffer = true, desc = "grug-far：中止操作" })

				-- 关闭缓冲区（会提示进行中的操作）
				vim.keymap.set("n", "<leader>c", function()
					require("grug-far").get_instance(0):close()
				end, { buffer = true, desc = "grug-far：关闭" })

				-- 在快速修复列表中打开结果
				vim.keymap.set("n", "<leader>qf", function()
					require("grug-far").get_instance(0):open_quickfix()
				end, { buffer = true, desc = "grug-far：打开快速修复列表" })

				-- 预览当前结果位置
				vim.keymap.set("n", "<leader>p", function()
					require("grug-far").get_instance(0):preview_location()
				end, { buffer = true, desc = "grug-far：预览结果位置" })

				-- 显示/隐藏完整 CLI 命令
				vim.keymap.set("n", "<leader>sc", function()
					require("grug-far").get_instance(0):toggle_show_command()
				end, { buffer = true, desc = "grug-far：显示/隐藏命令" })

				-- 切换替换解释器（Lua/Vimscript）
				vim.keymap.set("n", "<leader>si", function()
					require("grug-far").get_instance(0):swap_replacement_interpreter()
				end, { buffer = true, desc = "grug-far：切换替换解释器" })
			end,
		})
	end,
}
