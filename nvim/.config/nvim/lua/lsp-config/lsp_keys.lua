local M = {}

local Store = require("nvim-store3").project()
local lsp_get = require("lsp-config.lsp_utils")

---------------------------------------------------------
-- 重启 LSP
---------------------------------------------------------
local function restart_lsp()
	local clients = vim.lsp.get_clients()
	for _, client in ipairs(clients) do
		client:stop(true)
	end

	vim.defer_fn(function()
		local lsp_name = lsp_get.get_lsp_name()
		vim.lsp.enable(lsp_name, true)
	end, 500)
end

---------------------------------------------------------
-- 切换 LSP 状态（项目级）
---------------------------------------------------------
local function toggle_lsp()
	local lsp_names = lsp_get.get_lsp_by_filetype(vim.bo.filetype)

	vim.ui.select(lsp_names, {
		prompt = "选择 LSP 客户端：",
		format_item = function(item)
			local state = Store:get("lsp." .. item)
			return string.format("%-20s • 状态: %s", item, state or "active")
		end,
	}, function(selected)
		if not selected then
			return
		end

		local key = "lsp." .. selected
		local state = Store:get(key)

		if state == "inactive" then
			vim.lsp.enable(selected, true)
			Store:set(key, "active")
		else
			vim.lsp.enable(selected, false)
			Store:set(key, "inactive")
		end

		vim.schedule(vim.cmd.redrawstatus)
	end)
end

---------------------------------------------------------
-- 诊断 Quickfix / Loclist
---------------------------------------------------------
function M.open_all_diagnostics()
	vim.diagnostic.setqflist({
		open = true,
		title = "Project Diagnostics",
		severity = { min = vim.diagnostic.severity.WARN },
	})
end

function M.open_buffer_diagnostics()
	vim.diagnostic.setloclist({
		open = true,
		title = "Buffer Diagnostics",
		severity = { min = vim.diagnostic.severity.HINT },
	})
end

---------------------------------------------------------
-- 复制错误信息
---------------------------------------------------------
local function CopyErrorMessage()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local bufnr = vim.api.nvim_get_current_buf()
	local diag = vim.diagnostic.get(bufnr, { lnum = row })

	if #diag == 0 then
		vim.notify("No diagnostics found.", vim.log.levels.WARN)
		return
	end

	table.sort(diag, function(a, b)
		return a.severity < b.severity
	end)

	local messages = {}
	local all = ""

	for _, d in ipairs(diag) do
		local msg = string.format(
			"[%s] %s [%s] - %s",
			vim.diagnostic.severity[d.severity],
			d.message,
			d.code or "No code",
			d.source or "?"
		)
		all = all .. msg .. "\n"
		table.insert(messages, msg)
	end

	if #messages == 1 then
		vim.fn.setreg("+", messages[1])
		vim.fn.setreg('"', messages[1])
		return
	end

	local choices = { "Copy all" }
	vim.list_extend(choices, messages)

	vim.ui.select(choices, {
		prompt = "Select message to copy:",
	}, function(choice, idx)
		if not choice then
			return
		end

		if idx == 1 then
			local trimmed = vim.trim(all)
			vim.fn.setreg("+", trimmed)
			vim.fn.setreg('"', trimmed)
		else
			local msg = messages[idx - 1]
			vim.fn.setreg("+", msg)
			vim.fn.setreg('"', msg)
		end
	end)
end

---------------------------------------------------------
-- 按键映射
---------------------------------------------------------
local keymaps = {
	{
		"<s-a-d>",
		function()
			local key = "lsp.diagnostics"
			local state = Store:get(key)

			if state == "off" then
				vim.diagnostic.enable(true)
				Store:set(key, "on")
			else
				vim.diagnostic.enable(false)
				Store:set(key, "off")
			end
		end,
		"LSP: toggle diagnostics",
	},
	{
		"<s-a-i>",
		function()
			local key = "lsp.inlay_hints"
			local state = Store:get(key)

			if state == "off" then
				vim.lsp.inlay_hint.enable(true)
				Store:set(key, "on")
			else
				vim.lsp.inlay_hint.enable(false)
				Store:set(key, "off")
			end
		end,
		"LSP: toggle inlay hints",
	},
	{
		"<leader>yd",
		CopyErrorMessage,
		"LSP: copy diagnostics",
	},
}

M.set_keymaps = function(bufnr)
	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], {
			noremap = true,
			silent = true,
			desc = map[3],
			buffer = bufnr,
		})
	end
end

M.global_keymaps = function()
	vim.keymap.set("n", "<leader>rl", function()
		restart_lsp()
	end, { noremap = true, silent = true, desc = "LSP: 重启lsp" })

	vim.keymap.set("n", "<leader>st", function()
		toggle_lsp()
	end, { desc = "Toggle LSP for current filetype" })

	vim.keymap.set("n", "<leader>sg", function()
		vim.cmd("tabnew " .. vim.lsp.log.get_filename())
	end, { desc = "lsp log" })

	vim.keymap.set("n", "<leader>yd", function()
		CopyErrorMessage()
	end, { noremap = true, silent = true, desc = "LSP: 复制lsp诊断" })

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
