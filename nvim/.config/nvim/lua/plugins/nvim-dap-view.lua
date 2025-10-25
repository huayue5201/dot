-- https://github.com/igorlfs/nvim-dap-view?tab=readme-ov-file#expanding-variables

return {
	"igorlfs/nvim-dap-view",
	lazy = true,
	config = function()
		-- 设置自定义高亮颜色
		vim.api.nvim_set_hl(0, "ViewBreakpoints", { fg = "#FF3030" }) -- 红色
		vim.api.nvim_set_hl(0, "ViewScopes", { fg = "#FFD700" }) -- 金色
		vim.api.nvim_set_hl(0, "ViewExceptions", { fg = "#20B2AA" }) -- 海蓝色
		vim.api.nvim_set_hl(0, "ViewWatch", { fg = "#8B7E66", bg = nil }) -- 橙色
		vim.api.nvim_set_hl(0, "ViewThreads", { fg = "#8B4789" }) -- 紫红色
		vim.api.nvim_set_hl(0, "ViewREPL", { fg = "#228B22" }) -- 绿色
		vim.api.nvim_set_hl(0, "ViewConsole", { fg = "#FF7F00" }) -- 淡紫色

		-- 引入 nvim-dap-view 插件并配置
		local dv = require("dap-view")

		-- 配置快捷键切换 nvim-dap-view
		vim.keymap.set("n", "<leader>dv", function()
			dv.toggle(true)
		end, { desc = "切换 nvim-dap-view" })

		vim.keymap.set("n", "<localleader>w", "<cmd>DapViewJump watches<cr>", { desc = "dap-view watches" })
		vim.keymap.set("n", "<localleader>s", "<cmd>DapViewJump scopes<cr>", { desc = "dap-view scopes" })
		vim.keymap.set("n", "<localleader>e", "<cmd>DapViewJump exceptions<cr>", { desc = "dap-view exceptions" })
		vim.keymap.set("n", "<localleader>b", "<cmd>DapViewJump breakpoints<cr>", { desc = "dap-view breakpoints" })
		vim.keymap.set("n", "<localleader>t", "<cmd>DapViewJump threads<cr>", { desc = "dap-view threads" })
		vim.keymap.set("n", "<localleader>r", "<cmd>DapViewJump repl<cr>", { desc = "dap-view repl" })
		vim.keymap.set("n", "<localleader>c", "<cmd>DapViewJump console<cr>", { desc = "dap-view repl" })
		-- 配置添加/删除观察点
		vim.keymap.set("n", "<leader>dav", "<cmd>DapViewWatch<cr>", { desc = "添加/删除观察点" })
	end,
}
