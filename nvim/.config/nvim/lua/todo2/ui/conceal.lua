-- lua/todo/ui/conceal.lua
local M = {}

function M.setup_conceal_syntax(bufnr)
	vim.cmd(string.format(
		[[
        buffer %d
        syntax match markdownTodo /\[\s\]/ conceal cchar=☐
        syntax match markdownTodoDone /\[[xX]\]/ conceal cchar=☑
        highlight default link markdownTodo Conceal
        highlight default link markdownTodoDone Conceal
    ]],
		bufnr
	))
end

function M.apply_conceal(bufnr)
	local win = vim.fn.bufwinid(bufnr)
	if win == -1 then
		return
	end

	vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
	vim.api.nvim_set_option_value("concealcursor", "ncv", { win = win })

	M.setup_conceal_syntax(bufnr)
end

return M
