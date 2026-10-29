-- https://github.com/leoluz/nvim-dap-go
-- 全 eager 加载（本仓不使用 ft 懒加载）
-- 只保留 Go 测试相关的两个入口：<leader>dT / <leader>dY
-- （<leader>dt 已被 lua/dap_ext/dap_keys.lua 的「启用/禁用断点」占用，不能覆盖）

return {
	"leoluz/nvim-dap-go",
	dependencies = {
		"mfussenegger/nvim-dap",
		"igorlfs/nvim-dap-view",
	},
	config = function(_, opts)
		require("dap-go").setup(opts)

		-- 静态绑定即可：ft=go 时插件才加载，不需要按 session 动态增删键位
		vim.keymap.set("n", "<leader>dT", function()
			require("dap-go").debug_test()
		end, { desc = "[D]ap [T]est debug (closest)" })

		vim.keymap.set("n", "<leader>dY", function()
			require("dap-go").debug_last_test()
		end, { desc = "[D]ap [Y] last test debug" })
	end,

	opts = {
		-- 默认已有 Debug / Debug Test / Attach，这里只补一个「调试整个包」
		dap_configurations = {
			{ type = "go", name = "Debug", request = "launch", mode = "debug", program = "${file}" },
			{ type = "go", name = "Debug Package", request = "launch", mode = "debug", program = "${workspaceFolder}" },
			{ type = "go", name = "Debug Test", request = "launch", mode = "test", program = "${workspaceFolder}" },
			{ type = "go", name = "Attach", request = "attach", mode = "remote" },
		},

		delve = {
			path = "dlv", -- dlv 可执行程序路径（~/go/bin/dlv）
			initialize_timeout_sec = 20,
			port = "${port}", -- 动态端口
			args = {},
			build_flags = {},
			detached = vim.fn.has("win32") == 0, -- Windows 上通常设 false
			cwd = nil,
		},

		tests = {
			verbose = false,
		},
	},
}
