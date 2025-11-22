-- https://github.com/leoluz/nvim-dap-go

return {
	"leoluz/nvim-dap-go",
	ft = { "go" },
	dependencies = {
		"mfussenegger/nvim-dap",
		"rcarriga/nvim-dap-ui",
	},
	config = function(_, opts)
		-- 启动 nvim-dap-go
		require("dap-go").setup(opts)

		local dap = require("dap")

		-- 临时表存储 session keymaps
		local session_keymaps = {}

		-- DAP 启动时绑定
		dap.listeners.after.event_initialized["project_dap_keymaps"] = function()
			-- 保存绑定的 buffer / keymap id
			session_keymaps = {}

			local opts = { noremap = true, silent = true }
			-- 只在 normal 模式
			table.insert(
				session_keymaps,
				vim.keymap.set("n", "<leader>dt", function()
					require("dap-go").debug_test()
				end, vim.tbl_extend("force", opts, { desc = "Debug Go Test (closest)" }))
			)

			table.insert(
				session_keymaps,
				vim.keymap.set("n", "<leader>dT", function()
					require("dap-go").debug_last_test()
				end, vim.tbl_extend("force", opts, { desc = "Debug Last Go Test" }))
			)
		end

		-- DAP 结束时清理
		dap.listeners.before.event_terminated["project_dap_keymaps"] = function()
			for _, id in ipairs(session_keymaps) do
				vim.keymap.del("n", id)
			end
			session_keymaps = {}
		end
		dap.listeners.before.event_exited["project_dap_keymaps"] = function()
			for _, id in ipairs(session_keymaps) do
				vim.keymap.del("n", id)
			end
			session_keymaps = {}
		end
		-- -- 推荐 keymap（你可以按自己习惯改）
		-- vim.keymap.set("n", "<leader>dt", function()
		-- 	require("dap-go").debug_test()
		-- end, { desc = "Debug Go Test (closest)" })
		--
		-- vim.keymap.set("n", "<leader>dT", function()
		-- 	require("dap-go").debug_last_test()
		-- end, { desc = "Debug Last Go Test" })
	end,

	-- 这里是默认配置 +你可以覆盖的选项
	opts = {
		dap_configurations = {
			-- 默认已经有几种：Debug Main, Debug Test, Attach Remote
			{ type = "go", name = "Debug", request = "launch", mode = "debug", program = "${file}" },
			{ type = "go", name = "Debug Package", request = "launch", mode = "debug", program = "${workspaceFolder}" },
			{ type = "go", name = "Debug Test", request = "launch", mode = "test", program = "${workspaceFolder}" },
			{ type = "go", name = "Attach", request = "attach", mode = "remote" },
		},

		delve = {
			path = "dlv", -- dlv 可执行程序路径
			initialize_timeout_sec = 20, -- 等待 dlv 启动超时时间
			port = "${port}", -- 使用动态端口
			args = {}, -- 向 dlv 传递额外参数
			build_flags = {}, -- 编译时 build flags，例如 `{"-tags=integration"}`
			detached = vim.fn.has("win32") == 0, -- 是否以 detached 模式启动 dlv，Windows 上通常设 false
			cwd = nil, -- 调试时的工作目录 (默认使用 cwd)
		},

		tests = {
			verbose = false, -- 是否以 verbose 模式运行测试
		},
	},
}
