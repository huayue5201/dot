local picker = require("dap-config.debug-file-picker")

return {
	setup = function(dap)
		-- Rust GDB Adapter 配置
		dap.adapters["rust-gdb"] = {
			type = "executable",
			command = "rust-gdb",
			args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
		}

		-- 工具函数：从 Cargo JSON 输出获取可执行文件
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

		-- 工具函数：选择可执行文件（现代交互 + fallback）
		local function select_target(cmd)
			local targets = get_targets(cmd)
			if #targets == 0 then
				-- fallback 到 picker
				return picker.option() or vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
			elseif #targets == 1 then
				return targets[1]
			else
				local choice, choice_made = nil, false
				local items = {}
				for _, target in ipairs(targets) do
					local parts = vim.split(target, package.config:sub(1, 1), { trimempty = true })
					table.insert(items, { display = parts[#parts], value = target })
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

		-- Rust 调试配置
		dap.configurations.rust = {
			{
				name = "Launch",
				type = "rust-gdb",
				request = "launch",
				program = function()
					return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
				end,
				args = {},
				cwd = "${workspaceFolder}",
				stopAtBeginningOfMainSubprogram = false,
			},
			{
				name = "Launch (+args)",
				type = "rust-gdb",
				request = "launch",
				program = function()
					return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
				end,
				args = read_args,
				cwd = "${workspaceFolder}",
				stopAtBeginningOfMainSubprogram = false,
			},
			{
				name = "Select and attach to process",
				type = "rust-gdb",
				request = "attach",
				program = function()
					return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
				end,
				pid = function()
					local name = vim.fn.input("Executable name (filter): ")
					return require("dap.utils").pick_process({ filter = name })
				end,
				cwd = "${workspaceFolder}",
			},
			{
				name = "Attach to gdbserver :1234",
				type = "rust-gdb",
				request = "attach",
				target = "localhost:1234",
				program = function()
					return select_target({ "cargo", "build", "--bins", "--quiet", "--message-format=json" })
				end,
				cwd = "${workspaceFolder}",
			},
		}
		require("dap.ext.vscode").type_to_filetypes["rust-gdb"] = { "rust" }
	end,
}
