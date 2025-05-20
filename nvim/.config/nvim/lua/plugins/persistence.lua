-- https://github.com/folke/persistence.nvim

return -- Lua
{
	"huayue5201/persistence.nvim",
	event = "VeryLazy",
	config = function()
		require("persistence").setup({
			dir = vim.fn.stdpath("state") .. "/sessions/", -- directory where session files are saved
			-- minimum number of file buffers that need to be open to save
			-- Set to 0 to always save
			need = 1,
			branch = true, -- use git branch to save session
		})
		-- 加载当前目录的会话
		vim.keymap.set("n", "<leader>ss", function()
			require("persistence").load()
		end, { desc = "加载当前目录的会话" })

		-- 选择一个会话进行加载
		vim.keymap.set("n", "<leader>sS", function()
			require("persistence").select()
		end, { desc = "选择会话进行加载" })

		-- 加载上一次的会话
		vim.keymap.set("n", "<leader>sl", function()
			require("persistence").load({ last = true })
		end, { desc = "加载上一次的会话" })

		-- 停止会话保存（本次退出不再自动保存）
		vim.keymap.set("n", "<leader>sd", function()
			require("persistence").stop()
		end, { desc = "停止会话保存" })

		vim.keymap.set("n", "<leader>sr", require("persistence").delete, { desc = "删除会话" })
	end,
}
