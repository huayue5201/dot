-- https://github.com/MagicDuck/grug-far.nvim

-- 先延迟加载插件
vim.g.later(function()
	-- 加载 grug-far 插件
	vim.g.add({ source = "MagicDuck/grug-far.nvim" })

	-- 配置 grug-far 插件
	require("grug-far").setup()

	-- 启动时使用当前光标下的单词作为搜索内容
	vim.keymap.set("n", "<leader>fs", function()
		require("grug-far").open({ prefills = { search = vim.fn.expand("<cword>") } })
	end, { desc = "Search with current word under cursor" })

	-- 启动时使用 ast-grep 引擎
	vim.keymap.set("n", "<leader>fa", function()
		require("grug-far").open({ engine = "astgrep" })
	end, { desc = "Search with AST engine" })

	-- 启动为临时缓冲区，关闭后删除
	vim.keymap.set("n", "<leader>ft", function()
		require("grug-far").open({ transient = true })
	end, { desc = "Open as a transient buffer" })

	-- 限制搜索/替换仅限于当前文件
	vim.keymap.set("n", "<leader>ff", function()
		require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
	end, { desc = "Limit search/replace to current file" })

	-- 使用当前可视选择，搜索当前文件
	vim.keymap.set("v", "<leader>fv", function()
		require("grug-far").with_visual_selection({ prefills = { paths = vim.fn.expand("%") } })
	end, { desc = "Search with current visual selection in current file" })

	-- 切换 grug-far 实例的可见性，并设置固定标题
	vim.keymap.set("n", "<leader>ft", function()
		require("grug-far").toggle_instance({ instanceName = "far", staticTitle = "Find and Replace" })
	end, { desc = "Toggle grug-far instance visibility" })

	-- 创建本地键绑定，切换 `--fixed-strings` 标志
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("my-grug-far-custom-keybinds", { clear = true }),
		pattern = { "grug-far" },
		callback = function()
			vim.keymap.set("n", "<localleader>w", function()
				local state = unpack(require("grug-far").toggle_flags({ "--fixed-strings" }))
				vim.notify("grug-far: toggled --fixed-strings " .. (state and "ON" or "OFF"))
			end, { buffer = true })
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
			end, { buffer = true })
		end,
	})
end)
