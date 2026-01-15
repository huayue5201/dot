-- ~/.config/nvim/lua/dap-config/rust-lldb.lua
--[[
Rust / C / C++ 的统一 LLDB 调试配置模块
------------------------------------------------------------
设计目标：
1. 统一管理 codelldb adapter 与多语言调试配置
2. 自动解析 cargo JSON 输出，智能选择可执行文件
3. 提供现代化的 UI 交互（vim.ui.select）
4. 保持可维护性：所有语言共享 cfg 基础配置
5. 可扩展：未来可加入 test name 自动检测、pretty-printer 自动切换等

此模块由外部通过 require("dap-config.rust-lldb").setup(dap) 调用。
--]]

return {
	setup = function(dap)
		----------------------------------------------------------------------
		-- 1. 注册 codelldb Adapter
		--    注意：adapter 名称必须是 "codelldb"，否则 dap.configurations.* 找不到
		----------------------------------------------------------------------
		dap.adapters.codelldb = {
			type = "server",
			port = "${port}",
			executable = {
				command = "codelldb", -- 可替换为绝对路径
				args = { "--port", "${port}" },
				---@diagnostic disable-next-line: deprecated
				detached = vim.loop.os_uname().sysname ~= "Windows",
			},
		}

		----------------------------------------------------------------------
		-- 2. 基础调试配置（Rust / C / C++ 共用）
		--    cfg 是一个模板，后续通过 vim.tbl_extend("force") 生成语言专属配置
		----------------------------------------------------------------------
		local cfg = {
			name = "Debug",
			type = "codelldb",
			request = "launch",
			cwd = "${workspaceFolder}",
			stopOnEntry = false,

			-- Rust pretty-printers（可选）
			-- 说明：此处加载的是 rustup 自带的 lldb_lookup.py，而非 codelldb 内置版本
			initCommands = function()
				local rustc_sysroot = vim.fn.trim(vim.fn.system("rustc --print sysroot"))

				-- 导入 pretty-printer Python 模块
				local script_import = 'command script import "' .. rustc_sysroot .. '/lib/rustlib/etc/lldb_lookup.py"'

				-- 加载额外的 LLDB 命令
				local commands_file = rustc_sysroot .. "/lib/rustlib/etc/lldb_commands"
				local commands = {}

				local file = io.open(commands_file, "r")
				if file then
					for line in file:lines() do
						table.insert(commands, line)
					end
					file:close()
				end

				-- 将 import 插入到命令列表最前面
				table.insert(commands, 1, script_import)
				return commands
			end,
		}

		----------------------------------------------------------------------
		-- 3. 工具函数：解析 cargo JSON 输出，提取可执行文件路径
		--    用于自动选择 bin/test 目标
		----------------------------------------------------------------------
		--- Parse cargo --message-format=json output and extract executables
		---@param cmd table command list, e.g. { "cargo", "build", "--message-format=json" }
		---@return table list of executable paths
		local function get_targets(cmd)
			local out = vim.fn.systemlist(cmd)
			if vim.v.shell_error ~= 0 then
				vim.notify(table.concat(out, "\n"), vim.log.levels.ERROR)
				return {}
			end

			local targets = {}
			for _, line in ipairs(out) do
				local ok, json = pcall(vim.fn.json_decode, line)
				if ok and type(json) == "table" and json.reason == "compiler-artifact" and json.executable then
					-- 只接受 bin 或 test profile
					if vim.tbl_contains(json.target.kind, "bin") or json.profile.test then
						table.insert(targets, json.executable)
					end
				end
			end
			return targets
		end

		----------------------------------------------------------------------
		-- 4. 工具函数：智能选择可执行文件
		--    单目标 → 自动选
		--    多目标 → vim.ui.select
		--    无目标 → fallback 到手动输入
		----------------------------------------------------------------------
		--- Select executable target from cargo output
		---@param cmd table cargo command
		---@return string path
		local function select_target(cmd)
			local targets = get_targets(cmd)

			if #targets == 0 then
				-- 无可执行文件，手动输入
				return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
			elseif #targets == 1 then
				-- 单一目标，自动选择
				return targets[1]
			else
				-- 多目标，使用现代 UI 选择
				local choice = nil
				local choice_made = false

				local items = {}
				for _, target in ipairs(targets) do
					local parts = vim.split(target, package.config:sub(1, 1), { trimempty = true })
					table.insert(items, {
						display = parts[#parts], -- 仅显示文件名
						value = target,
					})
				end

				vim.ui.select(items, {
					prompt = "Select a target:",
					format_item = function(item)
						return item.display
					end,
				}, function(selected)
					if selected then
						choice = selected.value
					end
					choice_made = true
				end)

				-- 等待用户选择完成（阻塞式）
				while not choice_made do
					vim.wait(50)
				end

				---@diagnostic disable-next-line: return-type-mismatch
				return choice
			end
		end

		----------------------------------------------------------------------
		-- 5. 工具函数：读取命令行参数
		----------------------------------------------------------------------
		local function read_args()
			local input = vim.fn.input("Enter args: ")
			return vim.split(input, " ", { trimempty = true })
		end

		----------------------------------------------------------------------
		-- 6. C 语言调试配置
		--    通过 vim.tbl_extend("force") 复用 cfg
		----------------------------------------------------------------------
		dap.configurations.c = {
			vim.tbl_extend("force", cfg, {
				program = function()
					return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
				end,
			}),
			vim.tbl_extend("force", cfg, {
				name = "Debug (+args)",
				program = function()
					return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
				end,
				args = read_args,
			}),
			vim.tbl_extend("force", cfg, {
				name = "Attach debugger",
				request = "attach",
			}),
		}

		----------------------------------------------------------------------
		-- 7. C++ 配置：完全复用 C
		----------------------------------------------------------------------
		dap.configurations.cpp = vim.tbl_extend("keep", {}, dap.configurations.c)

		----------------------------------------------------------------------
		-- 8. Rust 调试配置
		--    使用 cargo JSON 自动选择 bin/test
		----------------------------------------------------------------------
		dap.configurations.rust = {
			-- Debug 二进制
			vim.tbl_extend("force", cfg, {
				program = function()
					return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
				end,
			}),

			-- Debug (+args)
			vim.tbl_extend("force", cfg, {
				name = "Debug (+args)",
				program = function()
					return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
				end,
				args = read_args,
			}),

			-- Debug tests
			vim.tbl_extend("force", cfg, {
				name = "Debug tests",
				program = function()
					return select_target({ "cargo", "test", "--no-run", "--message-format=json" })
				end,
				args = { "--test-threads=1" },
			}),

			-- Debug tests (+args)
			vim.tbl_extend("force", cfg, {
				name = "Debug tests (+args)",
				program = function()
					return select_target({ "cargo", "test", "--no-run", "--message-format=json" })
				end,
				args = function()
					return vim.list_extend(read_args(), { "--test-threads=1" })
				end,
			}),

			-- Debug 光标所在测试（未来可加入 Treesitter 自动检测）
			vim.tbl_extend("force", cfg, {
				name = "Debug test (cursor)",
				program = function()
					return select_target({ "cargo", "test", "--no-run", "--message-format=json" })
				end,
				args = function()
					local test_name = nil -- TODO: Treesitter 获取当前测试函数名
					return test_name and { "--exact", test_name, "--test-threads=1" } or { "--test-threads=1" }
				end,
			}),

			-- Attach
			vim.tbl_extend("force", cfg, {
				name = "Attach debugger",
				request = "attach",
				program = function()
					return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
				end,
			}),
		}
	end,
}
