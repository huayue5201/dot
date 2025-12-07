return {
	setup = function(dap)
		-- LLDB Adapter 配置
		dap.adapters.lldb = {
			type = "server",
			port = "${port}",
			executable = {
				command = "codelldb", -- 或者本地 codelldb 路径
				args = { "--port", "${port}" },
				detached = vim.loop.os_uname().sysname ~= "Windows",
			},
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

		-- 工具函数：选择可执行文件
		local function select_target(cmd)
			local targets = get_targets(cmd)
			if #targets == 0 then
				return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
			elseif #targets == 1 then
				return targets[1]
			else
				local choice, done = nil, false
				local items = {}
				for _, t in ipairs(targets) do
					local parts = vim.split(t, package.config:sub(1, 1), { trimempty = true })
					table.insert(items, { display = parts[#parts], value = t })
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
					done = true
				end)
				while not done do
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

		-- 基础配置
		local cfg_base = {
			type = "lldb",
			request = "launch",
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
		}

		-- 动态 Provider
		dap.providers.configs["rust-lldb"] = function(bufnr)
			return {
				{
					name = "Debug binary",
					type = "lldb",
					request = "launch",
					cwd = vim.fn.getcwd(),
					program = function()
						return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
					end,
				},
				{
					name = "Debug binary (+args)",
					type = "lldb",
					request = "launch",
					cwd = vim.fn.getcwd(),
					program = function()
						return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
					end,
					args = read_args,
				},
				{
					name = "Debug tests",
					type = "lldb",
					request = "launch",
					cwd = vim.fn.getcwd(),
					program = function()
						return select_target({ "cargo", "test", "--no-run", "--message-format=json" })
					end,
					args = { "--test-threads=1" },
				},
				{
					name = "Debug tests (+args)",
					type = "lldb",
					request = "launch",
					cwd = vim.fn.getcwd(),
					program = function()
						return select_target({ "cargo", "test", "--no-run", "--message-format=json" })
					end,
					args = function()
						return vim.list_extend(read_args(), { "--test-threads=1" })
					end,
				},
				{
					name = "Debug test (cursor)",
					type = "lldb",
					request = "launch",
					cwd = vim.fn.getcwd(),
					program = function()
						return select_target({ "cargo", "test", "--no-run", "--message-format=json" })
					end,
					args = function()
						local test_name = nil -- TODO: 使用 Treesitter 获取光标所在测试函数
						return test_name and { "--exact", test_name, "--test-threads=1" } or { "--test-threads=1" }
					end,
				},
				{
					name = "Attach debugger",
					type = "lldb",
					request = "attach",
					cwd = vim.fn.getcwd(),
					program = function()
						return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
					end,
				},
			}
		end

		-- 可选：指定类型对应的文件类型
		require("dap.ext.vscode").type_to_filetypes["rust-lldb"] = { "rust" }
	end,
}
