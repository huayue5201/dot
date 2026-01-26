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

		-- 切换 grug-far 实例可见性（避免与 fgt 冲突 → 使用 fgT）
		vim.keymap.set("n", "<leader>gT", function()
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

		-- 使用可视选择内容搜索当前文件
		vim.keymap.set("v", "<leader>gv", function()
			require("grug-far").with_visual_selection({
				prefills = { paths = vim.fn.expand("%") },
			})
		end, { desc = "grug-far：使用可视选择搜索当前文件" })

		vim.keymap.set({ "n", "x" }, "<leader>si", function()
			require("grug-far").open({ visualSelectionUsage = "operate-within-range" })
		end, { desc = "grug-far: Search within range" })
		----------------------------------------------------------------------
		-- FileType = grug-far 时的 buffer 内键位
		----------------------------------------------------------------------
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("grug-far-keymap", { clear = true }),
			pattern = "grug-far",
			callback = function()
				vim.keymap.set("n", "<left>", function()
					local win = vim.api.nvim_get_current_win()
					vim.api.nvim_win_set_cursor(win, { 2, 0 })
				end, { buffer = true, desc = "grug-far：跳回搜索输入框" })

				vim.keymap.set("n", "<C-s>", function()
					local state = unpack(require("grug-far").get_instance(0):toggle_flags({ "--fixed-strings" }))
					vim.notify("grug-far: toggled --fixed-strings " .. (state and "ON" or "OFF"))
				end, { buffer = true })
			end,
		})
	end,
}
