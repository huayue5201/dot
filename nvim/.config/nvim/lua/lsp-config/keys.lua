-- lua/lsp-config/keys.lua
---@brief LSP 按键绑定（只做映射，动作在 actions / servers）
local M = {}

local actions = require("lsp-config.actions")
local servers = require("lsp-config.servers")

---buffer 级映射（LspAttach 时调用）
---@param bufnr integer
function M.attach(bufnr)
	local keymaps = {
		{ "gro", actions.open_docs, "LSP: open external docs" },
		-- 不用 gO：Neovim 0.11+ 内建 gO = vim.lsp.buf.document_symbol()（符号大纲），
		-- code lens 用内建约定的 grx（这里覆盖成我们自己的实现，以正确处理 above 布局的
		-- 虚拟行偏移；内建 vim.lsp.codelens.run 在光标停在透镜那一屏行时取不到条目）。
		{ "grx", actions.run_code_lens, "LSP: run code lens (e.g. ▶ Run Test)" },
		{ "grd", actions.open_buffer_diagnostics, "LSP: buffer diagnostics" },
		{ "grD", actions.open_all_diagnostics, "LSP: workspace diagnostics" },
		{ "<leader>rtd", actions.toggle_diagnostics, "LSP: toggle diagnostics" },
		{ "<leader>rti", actions.toggle_inlay_hints, "LSP: toggle inlay hints" },
		{ "<leader>yd", actions.copy_diagnostics, "LSP: copy diagnostics" },
	}

	for _, map in ipairs(keymaps) do
		vim.keymap.set("n", map[1], map[2], {
			noremap = true,
			silent = true,
			desc = map[3],
			buffer = bufnr,
		})
	end
end

---全局映射
function M.global()
	vim.keymap.set("n", "<leader>rtL", servers.restart, { noremap = true, silent = true, desc = "LSP: 重启lsp" })

	vim.keymap.set("n", "<leader>rtl", servers.toggle, { desc = "Toggle LSP for current filetype" })

	vim.keymap.set("n", "<leader>rtp", function()
		require("lsp-config.panel").toggle()
	end, { desc = "LSP: 控制面板" })

	vim.keymap.set("n", "<leader>sL", actions.open_lsp_log, { desc = "lsp log" })

	vim.keymap.set("n", "]d", actions.jump_next, { desc = "Jump to next diagnostic (prioritized)" })

	vim.keymap.set("n", "[d", actions.jump_prev, { desc = "Jump to previous diagnostic (prioritized)" })
end

return M
