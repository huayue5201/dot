-- https://github.com/mfussenegger/nvim-dap
-- NOTE : https://github.com/Jorenar/nvim-dap-disasm 提供反汇编（disassembly)

return {
	"mfussenegger/nvim-dap",
	event = "VeryLazy",
	dependencies = {
		-- https://github.com/theHamsta/nvim-dap-virtual-text
		"theHamsta/nvim-dap-virtual-text",
		"Jorenar/nvim-dap-disasm",
	},
	config = function()
		-- repl 自动补全支持
		vim.cmd([[au FileType dap-repl lua require('dap.ext.autocompl').attach()]])

		vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#FF0000" })
		vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#FFDAB9" })
		vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#8B8B7A" })
		vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#00BFFF" })
		vim.api.nvim_set_hl(0, "YellowCursor", { fg = "#FFCC00", bg = "" })
		vim.api.nvim_set_hl(0, "YellowBack", { bg = "#4C4C19" })
		local signs = {
			DapBreakpoint = { text = "", texthl = "DapBreakpoint" }, -- 断点
			DapBreakpointCondition = { text = "", texthl = "DapBreakpointCondition" }, -- 条件断点
			DapBreakpointRejected = { text = "", texthl = "DapBreakpointRejected" }, -- 拒绝断点
			DapLogPoint = { text = "", texthl = "DapLogPoint" }, -- 日志点
			DapStopped = { -- 停止位置
				text = " ",
				texthl = "YellowCursor",
				linehl = "YellowBack",
				numhl = "",
			},
		}
		for name, opts in pairs(signs) do
			vim.fn.sign_define(name, opts)
		end

		local dap = require("dap")

		-- 自动开启和关闭调试界面[citation:3]
		local daps, dapui = dap, require("dapui")
		daps.listeners.after.event_initialized["dapui_config"] = function()
			dapui.open({})
		end
		daps.listeners.before.event_terminated["dapui_config"] = function()
			dapui.close({})
		end
		daps.listeners.before.event_exited["dapui_config"] = function()
			dapui.close({})
		end
		--  nvim-dap配置
		local dap_defaults = {
			switchbuf = "usevisible,usetab,newtab", -- 在调试时使用打开的缓冲区
			terminal_win_cmd = "belowright new", -- 设置终端窗口在底部打开
			focus_terminal = true, -- 打开终端时将焦点切换到终端
			autostart = "nluarepl", -- 自动启动 Lua REPL
			console = "integratedTerminal", -- 控制台设置
			stepping_granularity = "statement", -- `line` or `instructions`
			external_terminal = {
				command = "/usr/bin/alacritty", -- 外部终端的命令路径
				args = { "-e" }, -- 外部终端的参数
			},
		}
		-- 将配置应用到 dap.defaults.fallback
		for key, value in pairs(dap_defaults) do
			daps.defaults.fallback[key] = value
		end

		require("dap.dap_keys").setup()

		-- 扩展 REPL 命令
		local repl = require("dap.repl")
		repl.commands = vim.tbl_extend("force", repl.commands, {
			-- 添加 .copy 命令
			custom_commands = {
				[".copy"] = function(text)
					local evaluated = repl.execute(text, { context = "clipboard" })
					local result = evaluated.result
					-- 将结果放入系统剪贴板（+寄存器）
					vim.fn.setreg("+", result)
					-- 输出信息到 REPL
					daps.repl.append("Copied to clipboard: " .. result)
				end,
			},
		})

		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "dap-repl", "dap-view-term", "dap-view" },
			group = vim.api.nvim_create_augroup("dapui_keymaps", { clear = true }),
			desc = "Fix and add insert-mode keymaps for dap-repl",
			callback = function()
				vim.cmd("syntax on") -- 启用语法高亮（保险）
				-- vim.cmd("runtime! syntax/rust.vim") -- 手动加载 Rust 的语法文件
				vim.opt.signcolumn = "no" -- 禁用标志列
				-- 向下浏览补全项
				vim.keymap.set("i", "<tab>", function()
					if vim.fn.pumvisible() == 1 then
						return "<C-n>" -- Trigger completion
					else
						return "<Tab>" -- Default tab behavior
					end
				end, { buffer = true, expr = true, desc = "Tab Completion in dap-repl" })
				-- 向上浏览补全项
				vim.keymap.set("i", "<S-Tab>", function()
					if vim.fn.pumvisible() == 1 then
						return "<C-p>" -- 反向选择补全菜单中的前一个项
					else
						return "<Tab>" -- 默认 Tab 行为
					end
				end, { buffer = true, expr = true, desc = "Reverse Tab Completion in dap-repl" })
				-- 选择补全项
				vim.keymap.set("i", "<CR>", function()
					if vim.fn.pumvisible() == 1 then
						return "<C-y>" -- 选择当前补全项（确认补全）
					else
						return "<CR>" -- 默认行为：插入换行符
					end
				end, { buffer = true, expr = true, desc = "Confirm completion or Insert newline in dap-repl" })
			end,
		})

		-- local api = vim.api
		-- 使用局部变量避免全局污染
		-- local keymap_restore = {}
		-- local original_global_k = nil

		dap.listeners.after["event_initialized"]["me"] = function()
			-- 关闭lsp内嵌提示
			vim.lsp.inlay_hint.enable(false)
			-- 保存全局 K 键映射
			-- 	local global_maps = vim.api.nvim_get_keymap("n")
			-- 	for _, map in ipairs(global_maps) do
			-- 		if map.lhs == "K" then
			-- 			original_global_k = map
			-- 			break
			-- 		end
			-- 	end
			--
			-- 	-- 删除全局 K 键映射
			-- 	pcall(vim.keymap.del, "n", "K")
			--
			-- 	-- 保存并删除缓冲区本地映射
			-- 	for _, buf in ipairs(api.nvim_list_bufs()) do
			-- 		local keymaps = api.nvim_buf_get_keymap(buf, "n")
			-- 		for _, keymap in ipairs(keymaps) do
			-- 			if keymap.lhs == "K" then
			-- 				table.insert(keymap_restore, keymap)
			-- 				pcall(api.nvim_buf_del_keymap, buf, "n", "K")
			-- 			end
			-- 		end
			-- 	end
			--
			-- 	-- 设置新的全局映射
			-- 	vim.keymap.set("n", "K", function()
			-- 		require("dap.ui.widgets").hover()
			-- 	end, { silent = true, desc = "DAP Hover" })
		end

		dap.listeners.after["event_terminated"]["me"] = function()
			-- 开启lsp内嵌提示
			vim.lsp.inlay_hint.enable(true)
			-- -- 恢复缓冲区映射
			-- for _, keymap in ipairs(keymap_restore) do
			-- 	if keymap.rhs then
			-- 		pcall(
			-- 			api.nvim_buf_set_keymap,
			-- 			keymap.buffer,
			-- 			keymap.mode,
			-- 			keymap.lhs,
			-- 			keymap.rhs,
			-- 			{ silent = keymap.silent == 1 }
			-- 		)
			-- 	elseif keymap.callback then
			-- 		pcall(
			-- 			vim.keymap.set,
			-- 			keymap.mode,
			-- 			keymap.lhs,
			-- 			keymap.callback,
			-- 			{ buffer = keymap.buffer, silent = keymap.silent == 1 }
			-- 		)
			-- 	end
			-- end
			-- keymap_restore = {}
			--
			-- -- 删除调试用的 K 键映射
			-- pcall(vim.keymap.del, "n", "K")
			--
			-- -- 恢复原始全局映射
			-- if original_global_k then
			-- 	if original_global_k.rhs then
			-- 		pcall(vim.keymap.set, "n", "K", original_global_k.rhs, {
			-- 			silent = original_global_k.silent == 1,
			-- 			expr = original_global_k.expr == 1,
			-- 			nowait = original_global_k.nowait == 1,
			-- 		})
			-- 	elseif original_global_k.callback then
			-- 		pcall(vim.keymap.set, "n", "K", original_global_k.callback, {
			-- 			silent = original_global_k.silent == 1,
			-- 			expr = original_global_k.expr == 1,
			-- 			nowait = original_global_k.nowait == 1,
			-- 		})
			-- 	end
			-- 	original_global_k = nil
			-- end
		end

		local module_cache = {}
		local function load_modules_from_dir(dir)
			if not module_cache[dir] then
				local path = vim.fn.stdpath("config") .. "/" .. dir
				module_cache[dir] = vim.fn.globpath(path, "*.lua", false, true)
			end
			for _, file in ipairs(module_cache[dir]) do
				-- 用 sub 来提取模块名
				local module_name = file:sub(#vim.fn.stdpath("config") + 2, -5):gsub("/", ".")
				-- 修正模块名称去掉 "lua." 前缀
				module_name = module_name:sub(5) -- 移除前4个字符，即 "lua."
				-- 尝试加载模块
				local ok, mod_or_err = pcall(require, module_name)
				if not ok then
					print("Failed to load module '" .. module_name .. "': " .. mod_or_err)
					vim.notify("Failed to load module '" .. module_name .. "': " .. mod_or_err, vim.log.levels.ERROR)
				elseif mod_or_err.setup then
					mod_or_err.setup(daps)
				end
			end
		end
		-- 加载模块
		load_modules_from_dir("lua/dap/configs")

		vim.api.nvim_create_autocmd({ "VimLeave" }, {
			callback = function()
				-- 通过系统命令关闭 OpenOCD
				vim.fn.system("pkill openocd")
			end,
		})
	end,
}
