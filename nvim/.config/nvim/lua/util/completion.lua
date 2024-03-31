-- lua/util/completion.lua

local M = {}

M.compSetup = function()
	-- neovim核心完成配置
	vim.opt.completeopt = { "menu", "menuone", "noselect", "noinsert" }
	vim.opt.shortmess:append("c")
	local function tab_complete()
		if vim.fn.pumvisible() == 1 then
			-- navigate to next item in completion menu
			return "<Down>"
		end

		local c = vim.fn.col(".") - 1
		local is_whitespace = c == 0 or vim.fn.getline("."):sub(c, c):match("%s")

		if is_whitespace then
			-- insert tab
			return "<Tab>"
		end

		local lsp_completion = vim.bo.omnifunc == "v:lua.vim.lsp.omnifunc"

		if lsp_completion then
			-- trigger lsp code completion
			return "<C-x><C-o>"
		end

		-- suggest words in current buffer
		return "<C-x><C-n>"
	end

	local function tab_prev()
		if vim.fn.pumvisible() == 1 then
			-- navigate to previous item in completion menu
			return "<Up>"
		end

		-- insert tab
		return "<Tab>"
	end

	vim.keymap.set("i", "<Tab>", tab_complete, { expr = true })
	vim.keymap.set("i", "<S-Tab>", tab_prev, { expr = true })
end

-- 片段集成
local function expand_snippet(event)
	local comp = vim.v.completed_item
	local item = vim.tbl_get(comp, "user_data", "nvim", "lsp", "completion_item")

	-- Check that we were given a snippet
	if
		not item
		or not item.insertTextFormat
		or item.insertTextFormat == 1
		or not (item.kind == vim.lsp.protocol.CompletionItemKind.Snippet)
	then
		return
	end

	-- Remove the inserted text
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local lnum = cursor[1] - 1
	local start_char = cursor[2] - #comp.word
	vim.api.nvim_buf_set_text(event.buf, lnum, start_char, lnum, #line, { "" })

	-- Insert snippet
	local snip_text = vim.tbl_get(item, "textEdit", "newText") or item.insertText

	assert(snip_text, "Language server indicated it had a snippet, but no snippet text could be found!")

	-- warning: this api is not stable yet
	vim.snippet.expand(snip_text)
end

vim.api.nvim_create_autocmd("CompleteDone", {
	desc = "Expand LSP snippet",
	callback = expand_snippet,
})
-- 片段占位符映射
-- Control + f: Jump to next snippet placeholder
vim.keymap.set({ "i", "s" }, "<C-f>", function()
	-- warning: this api is not stable yet
	if vim.snippet.jumpable(1) then
		return "<cmd>lua vim.snippet.jump(1)<cr>"
	else
		return "<C-f>"
	end
end, { expr = true })

-- Control + b: Jump to previous snippet placeholder
vim.keymap.set({ "i", "s" }, "<C-b>", function()
	-- warning: this api is not stable yet
	if vim.snippet.jumpable(-1) then
		return "<cmd>lua vim.snippet.jump(-1)<cr>"
	else
		return "<C-b>"
	end
end, { expr = true })

-- Control + l: Exit current snippet
vim.keymap.set({ "i", "s" }, "<C-l>", function()
	-- warning: this api is not stable yet
	if vim.snippet.active() then
		return "<cmd>lua vim.snippet.exit()<cr>"
	else
		return "<C-l>"
	end
end, { expr = true })

return M
