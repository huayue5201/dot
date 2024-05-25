local M = {}

-- 定义codelldb调试适配器
M.setup_codelldb_adapter = function()
	local cmd = os.getenv("HOME") .. "/.local/share/nvim/mason/bin/codelldb"

	require("dap").adapters.codelldb = function(on_adapter)
		-- 请求系统获取一个空闲端口
		local tcp = vim.loop.new_tcp()
		tcp:bind("127.0.0.1", 0)
		local port = tcp:getsockname().port
		tcp:shutdown()
		tcp:close()

		-- 使用端口启动codelldb
		local stdout = vim.loop.new_pipe(false)
		local stderr = vim.loop.new_pipe(false)
		local opts = {
			stdio = { nil, stdout, stderr },
			args = { "--port", tostring(port) },
		}
		local handle
		local pid_or_err
		handle, pid_or_err = vim.loop.spawn(cmd, opts, function(code)
			stdout:close()
			stderr:close()
			handle:close()
			if code ~= 0 then
				print("codelldb退出，退出码为", code)
			end
		end)
		if not handle then
			vim.notify("运行codelldb时出错：" .. tostring(pid_or_err), vim.log.levels.ERROR)
			stdout:close()
			stderr:close()
			return
		end
		vim.notify("codelldb已启动，PID=" .. pid_or_err)
		stderr:read_start(function(err, chunk)
			assert(not err, err)
			if chunk then
				vim.schedule(function()
					require("dap.repl").append(chunk)
				end)
			end
		end)
		local adapter = {
			type = "server",
			host = "127.0.0.1",
			port = port,
		}
		-- 在告知nvim-dap连接之前，等待codelldb准备就绪并开始监听
		vim.defer_fn(function()
			on_adapter(adapter)
		end, 500)
	end
end

-- 配置C++调试
M.setup_cpp_configuration = function()
	require("dap").configurations.cpp = {
		{
			name = "runit",
			type = "codelldb",
			request = "launch",
			program = function()
				return vim.fn.input("可执行文件路径: ", vim.fn.getcwd() .. "/", "file")
			end,
			args = { "--log_level=all" },
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			terminal = "integrated",
			pid = function()
				local handle = io.popen("pgrep hw$")
				local result = handle:read()
				handle:close()
				return result
			end,
		},
	}

	-- 将C配置与C++配置相同
	require("dap").configurations.c = require("dap").configurations.cpp
	-- 将Rust配置与C++配置相同
	require("dap").configurations.rust = require("dap").configurations.cpp
end

-- 将配置函数暴露给外部
return M
