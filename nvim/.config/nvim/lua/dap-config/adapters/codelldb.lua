-- ~/.config/nvim/lua/dap-config/rust-lldb.lua
return {
	setup = function(dap)
		-- LLDB Adapter 配置
		dap.adapters.lldb = {
			type = "server",
			port = "${port}",
			executable = {
				command = "codelldb", -- 或者你本地 codelldb 的路径
				args = { "--port", "${port}" },
				detached = vim.loop.os_uname().sysname ~= "Windows",
			},
		}

		-- 默认调试配置
		local cfg = {
			name = "Debug",
			type = "lldb",
			request = "launch",
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
		}

		-- 工具函数：从 cargo JSON 输出中获取可执行文件
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
					if vim.tbl_contains(json.target.kind, "bin") or json.profile.test then
						table.insert(targets, json.executable)
					end
				end
			end
			return targets
		end

		-- 工具函数：选择可执行文件（现代交互 API）
		local function select_target(cmd)
			local targets = get_targets(cmd)
			if #targets == 0 then
				return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
			elseif #targets == 1 then
				return targets[1]
			else
				-- 异步选择
				local choice = nil
				local choice_made = false

				local items = {}
				for i, target in ipairs(targets) do
					local parts = vim.split(target, package.config:sub(1, 1), { trimempty = true })
					table.insert(items, {
						display = parts[#parts],
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

				-- 等待用户选择完成
				while not choice_made do
					vim.wait(50)
				end

				return choice
			end
		end

		-- 输入命令行参数
		local function read_args()
			local input = vim.fn.input("Enter args: ")
			return vim.split(input, " ", { trimempty = true })
		end

		-- C 语言配置
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
			vim.tbl_extend("force", cfg, { name = "Attach debugger", request = "attach" }),
		}

		-- C++ 配置和 C 相同
		dap.configurations.cpp = vim.tbl_extend("keep", {}, dap.configurations.c)

		-- Rust 配置
		dap.configurations.rust = {
			-- Debug二进制
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
			-- Debug 光标所在的测试函数
			vim.tbl_extend("force", cfg, {
				name = "Debug test (cursor)",
				program = function()
					return select_target({ "cargo", "test", "--no-run", "--message-format=json" })
				end,
				args = function()
					local test_name = nil -- TODO: 使用 Treesitter 获取光标所在测试函数
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
