local M = {}

local json_store = require("user.json_store")
local lsp_get = require("lsp-config.lsp_utils")

-- 重启当前缓冲区的 LSP 客户端
local function restart_lsp()
	-- 获取所有已启动的 LSP 客户端
	local clients = vim.lsp.get_clients()
	-- 遍历所有 LSP 客户端并请求停止
	for _, client in ipairs(clients) do
		client:stop(true) -- 使用 `true` 表示强制停止客户端
	end
	-- 延迟启动 LSP
	vim.defer_fn(function()
		local lsp_name = lsp_get.get_lsp_name()
		-- 假设 lsp.enable() 已经处理了启动逻辑
		vim.lsp.enable(lsp_name, true)
	end, 500)
end

-- 切换lsp状态
local function toggle_lsp()
	-- 获取当前缓冲区的所有相关 LSP 客户端名称
	local lsp_names = lsp_get.get_lsp_by_filetype(vim.bo.filetype)

	-- 使用 vim.ui.select 来让用户选择要停用或启动的 LSP 客户端
	vim.ui.select(lsp_names, {
		prompt = "🔄 选择 LSP 客户端：", -- 提示信息
		format_item = function(item)
			-- 获取当前 LSP 的状态
			local state = json_store.get("lsp", item)
			-- 美化显示：左对齐 LSP 名称，并展示状态，增加可读性
			return string.format("%-20s • 状态: %s", item, state or "未知")
		end,
	}, function(selected_lsp)
		if not selected_lsp then
			vim.notify("未选择 LSP 客户端.", vim.log.levels.INFO)
			return
		end

		-- 获取当前 LSP 客户端的状态
		local current_state = json_store.get("lsp", selected_lsp)

		if current_state == "inactive" then
			-- 启动 LSP 客户端
			vim.lsp.enable(selected_lsp, true)
			json_store.set("lsp", selected_lsp, "active")
			vim.notify(string.format("LSP '%s' 已启动。", selected_lsp), vim.log.levels.INFO)
		else
			-- 停用 LSP 客户端
			vim.lsp.enable(selected_lsp, false)
			json_store.set("lsp", selected_lsp, "inactive")
			vim.notify(string.format("LSP '%s' 已停止。", selected_lsp), vim.log.levels.INFO)
		end

		-- 刷新状态栏
		vim.schedule(function()
			vim.cmd.redrawstatus()
		end)
	end)
end

-- 打开所有 buffer 的诊断（Quickfix 风格，适合全局排查）
function M.open_all_diagnostics()
	---@diagnostic disable-next-line: param-type-mismatch
	vim.diagnostic.setqflist({
		open = true,
		title = "Project Diagnostics",
		severity = { min = vim.diagnostic.severity.WARN },
		format = function(d)
			return string.format(
				"[%s] %s (%s:%d)",
				vim.diagnostic.severity[d.severity],
				d.message,
				d.source or "?",
				d.lnum + 1
			)
		end,
	})
end

-- 仅当前 buffer 的诊断（Loclist 风格，适合局部修复）
function M.open_buffer_diagnostics()
	---@diagnostic disable-next-line: param-type-mismatch
	vim.diagnostic.setloclist({
		open = true,
		title = "Buffer Diagnostics",
		severity = { min = vim.diagnostic.severity.HINT },
		format = function(d)
			return string.format("[%s] %s (%s)", vim.diagnostic.severity[d.severity], d.message, d.source or "?")
		end,
	})
end

-- 复制光标处的错误信息（包括错误代码）
local function CopyErrorMessage()
	local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	local bufnr = vim.api.nvim_get_current_buf()
	local diag = vim.diagnostic.get(bufnr, { lnum = row })
	if #diag == 0 then
		vim.notify("No diagnostics found at cursor position.", vim.log.levels.WARN)
		return
	end

	-- 如果只有一条错误，直接复制
	if #diag == 1 then
		local diagnostic = diag[1]
		local code = diagnostic.code or "No code"
		local message = diagnostic.message or "No message"
		local source = diagnostic.source or "unknown"
		local severity = diagnostic.severity or vim.diagnostic.severity.ERROR
		local severity_text = "ERROR"
		if severity == vim.diagnostic.severity.WARN then
			severity_text = "WARN"
		elseif severity == vim.diagnostic.severity.INFO then
			severity_text = "INFO"
		elseif severity == vim.diagnostic.severity.HINT then
			severity_text = "HINT"
		end
		local message_text = string.format("[%s] %s [%s] - %s", severity_text, message, code, source)
		vim.fn.setreg("+", message_text)
		vim.fn.setreg('"', message_text)
		vim.notify("Error message copied to clipboard: " .. message_text, vim.log.levels.INFO)
		return
	end

	-- 多条错误，展示选择框
	local messages = {}
	for _, diagnostic in ipairs(diag) do
		local code = diagnostic.code or "No code"
		local message = diagnostic.message or "No message"
		local source = diagnostic.source or "unknown"
		local severity = diagnostic.severity or vim.diagnostic.severity.ERROR
		local severity_text = "ERROR"
		if severity == vim.diagnostic.severity.WARN then
			severity_text = "WARN"
		elseif severity == vim.diagnostic.severity.INFO then
			severity_text = "INFO"
		elseif severity == vim.diagnostic.severity.HINT then
			severity_text = "HINT"
		end
		table.insert(messages, {
			text = string.format("[%s] %s [%s] - %s", severity_text, message, code, source),
			diagnostic = diagnostic,
		})
	end

	local choices = {}
	for _, msg in ipairs(messages) do
		table.insert(choices, msg.text)
	end

	vim.ui.select(choices, {
		prompt = "Select an error message to copy:",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if choice and idx then
			vim.fn.setreg("+", messages[idx].text)
			vim.fn.setreg('"', messages[idx].text)
			vim.notify("Error message copied to clipboard: " .. messages[idx].text, vim.log.levels.INFO)
		else
			vim.notify("No error message selected.", vim.log.levels.WARN)
		end
	end)
end

-- 定义一个函数来列出当前缓冲区的活动 LSP 客户端
local function list_active_lsps()
	local lsps = require("lsp-config.lsp_utils").get_active_lsps(0)
	if #lsps == 0 then
		print("No active LSP clients for this buffer.")
		return
	end
	print("Active LSPs:")
	for _, lsp in ipairs(lsps) do
		print(string.format("- %s (root: %s)", lsp.name, lsp.root_dir or "nil"))
	end
end

-- 按键映射
local keymaps = {
	-- { "gd", "<Cmd>lua vim.lsp.buf.definition()<CR>", "跳转到定义" },
	{
		"gro",
		function()
			require("lsp-config.externalDocs").open_docs()
		end,
		"LSP: open external docs",
	},
	{
		"<s-a-d>",
		function()
			local diagnostics_enabled = json_store.get("lsp", "diagnostics")
			if diagnostics_enabled == "off" then
				vim.diagnostic.enable(true)
				json_store.set("lsp", "diagnostics", "on")
			else
				vim.diagnostic.enable(false)
				json_store.set("lsp", "diagnostics", "off")
			end
		end,
		"LSP: toggle diagnostics",
	},
	{
		"<leader>ld",
		function()
			M.open_buffer_diagnostics()
		end,
		"LSP: buffer diagnostics",
	},
	{
		"<leader>lD",
		function()
			M.open_all_diagnostics()
		end,
		"LSP: workspace diagnostics",
	},
	{
		"<s-a-i>",
		function()
			local inlay_hint_enable = json_store.get("lsp", "inlay_hints")
			if inlay_hint_enable == "off" then
				vim.lsp.inlay_hint.enable(true)
				json_store.set("lsp", "inlay_hints", "on")
			else
				vim.lsp.inlay_hint.enable(false)
				json_store.set("lsp", "inlay_hints", "off")
			end
		end,
		"LSP: toggle inlay hints",
	},

	{
		"<leader>lw",
		function()
			list_active_lsps()
		end,
		"LSP: list workspace folders",
	},
}

-- 设置按键映射
M.set_keymaps = function(bufnr)
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], { noremap = true, silent = true, desc = map[3], buffer = bufnr })
	end
end

-- 删除按键映射
M.remove_keymaps = function(bufnr)
	for _, map in ipairs(keymaps) do
		pcall(vim.keymap.del, "n", map[1], { buffer = bufnr })
	end
end

M.global_keymaps = function()
	vim.keymap.set("n", "<leader>rl", function()
		restart_lsp()
	end, { noremap = true, silent = true, desc = "LSP: 重启lsp" })

	vim.keymap.set("n", "<leader>lt", function()
		toggle_lsp()
	end, { desc = "Toggle LSP for current filetype" })

	vim.keymap.set("n", "<leader>yd", function()
		CopyErrorMessage()
	end, { noremap = true, silent = true, desc = "LSP: 复制lsp诊断" })

	vim.keymap.set("n", "grh", function()
		require("lsp-config.prepareCallHierarchy").open_call_tree()
	end, { desc = "LSP: call tree visualization" })

	-- vim.keymap.set("i", "<C-CR>", function()
	-- 	if not vim.lsp.inline_completion.get() then
	-- 		return "<C-CR>"
	-- 	end
	-- end, {
	-- 	expr = true,
	-- 	replace_keycodes = true,
	-- 	desc = "Get the current inline completion",
	-- })
end

return M
