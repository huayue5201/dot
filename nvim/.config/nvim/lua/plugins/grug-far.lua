-- https://github.com/MagicDuck/grug-far.nvim

return {
	"MagicDuck/grug-far.nvim",
	event = "VeryLazy",
	config = function()
		require("grug-far").setup({
			helpLine = {
				enabled = false,
			},
			-- showCompactInputs = true,
			showInputsTopPadding = false,
			showInputsBottomPadding = false,
		})

		-- 启动时使用当前光标下的单词作为搜索内容
		vim.keymap.set("n", "<leader>fs", function()
			require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
		end, { desc = "使用光标下的单词进行搜索" })

		-- 启动时使用 ast-grep 引擎
		vim.keymap.set("n", "<leader>fa", function()
			require("grug-far").open({ engine = "astgrep" })
		end, { desc = "使用 AST 引擎进行搜索" })

		-- 启动为临时缓冲区，关闭后删除
		vim.keymap.set("n", "<leader>ft", function()
			require("grug-far").open({ transient = true })
		end, { desc = "以临时缓冲区打开（关闭后删除）" })

		-- 限制搜索/替换仅限于当前文件
		vim.keymap.set("n", "<leader>fr", function()
			require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
		end, { desc = "限制搜索/替换范围为当前文件" })

		-- 使用当前可视选择，搜索当前文件
		vim.keymap.set("v", "<leader>fv", function()
			require("grug-far").with_visual_selection({ prefills = { paths = vim.fn.expand("%") } })
		end, { desc = "使用当前可视选择内容，在当前文件中搜索" })

		-- 切换 grug-far 实例的可见性，并设置固定标题
		vim.keymap.set("n", "<leader>ft", function()
			require("grug-far").toggle_instance({ instanceName = "far", staticTitle = "Find and Replace" })
		end, { desc = "切换 grug-far 实例可见性" })

		-- 创建本地键绑定，切换 `--fixed-strings` 标志
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("my-grug-far-custom-keybinds", { clear = true }),
			pattern = { "grug-far" },
			callback = function()
				vim.keymap.set("n", "<localleader>w", function()
					local state = unpack(require("grug-far").toggle_flags({ "--fixed-strings" }))
					vim.notify("grug-far: toggled --fixed-strings " .. (state and "ON" or "OFF"))
				end, { buffer = true, desc = "切换 --fixed-strings 标志" })
			end,
		})

		-- 创建本地键绑定，打开一个结果并立即关闭 grug-far
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("grug-far-keybindings", { clear = true }),
			pattern = { "grug-far" },
			callback = function()
				vim.api.nvim_buf_set_keymap(0, "n", "<C-enter>", "<localleader>o<localleader>c", {})
			end,
		})

		-- 创建本地键绑定，跳回到搜索输入框
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("grug-far-keymap", { clear = true }),
			pattern = { "grug-far" },
			callback = function()
				-- 跳回搜索输入框，按左箭头即可
				vim.keymap.set("n", "<left>", function()
					vim.api.nvim_win_set_cursor(vim.fn.bufwinid(0), { 2, 0 })
				end, { buffer = true, desc = "跳回搜索输入框" })
			end,
		})
	end,
}
