-- 导入 codelldb 模块
local codelldb = require("dap-server.codelldb")

-- 选择调试器的函数
local function select_debugger()
	local debuggers = {
		"codelldb",
		-- 在这里添加其他调试器的名称
	}

	local debugger_list = {}
	for _, debugger in ipairs(debuggers) do
		table.insert(debugger_list, debugger)
	end

	-- 使用 vim.fn.inputlist() 函数选择调试器
	local selected_index = vim.fn.inputlist(debugger_list)
	if selected_index ~= -1 then
		local selected_debugger = debuggers[selected_index]
		if selected_debugger == "codelldb" then
			-- 根据选择的调试器配置 codelldb
			-- 这里仅需要调用 codelldb.setup_codelldb_adapter()，无需传入参数
			codelldb.setup_codelldb_adapter()
		end
	else
		vim.api.nvim_err_writeln("无效的选择。")
	end
end

-- 导出选择调试器的函数
return select_debugger
