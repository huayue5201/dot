local replace_map = {
	["true"] = "false",
	["false"] = "true",
	["True"] = "False",
	["False"] = "True",
	["set_low"] = "set_high",
	["set_high"] = "set_low",
}

local function toggle_or_default(default_key)
	local word = vim.fn.expand("<cword>")
	local new_word = replace_map[word]

	local keys = new_word and ("ciw" .. new_word .. "<Esc>") or default_key
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

vim.keymap.set("n", "<C-a>", function()
	toggle_or_default("<C-a>")
end, { desc = "Increment number or toggle boolean" })

vim.keymap.set("n", "<C-x>", function()
	toggle_or_default("<C-x>")
end, { desc = "Decrement number or toggle boolean" })
