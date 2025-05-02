local replace_map = {
	["true"] = "false",
	["false"] = "true",
	["True"] = "False",
	["False"] = "True",
	["set_low"] = "set_high",
	["set_high"] = "set_low",
	["GPIO_PIN_RESET"] = "GPIO_PIN_SET",
	["GPIO_PIN_SET"] = "GPIO_PIN_RESET",
}

local lsp = vim.lsp
local ms = vim.lsp.protocol.Methods
local util = vim.lsp.util

---@type "a" | "b" | "c"
local enum = "c"

---@return lsp.CompletionItem[]
local function get_lsp_items(params)
	local results = lsp.buf_request_sync(0, ms.textDocument_completion, params)
	local items = {}
	if results and not vim.tbl_isempty(results) then
		for _, obj in ipairs(results) do
			local result = obj.result
			if result then
				items = vim.iter(result.items)
					:filter(function(item)
						return item.kind == lsp.protocol.CompletionItemKind.EnumMember
					end)
					:totable()
			end

			if not vim.tbl_isempty(items) then
				break
			end
		end
	end
	return items
end

local function toggle_or_default(default_key)
	local word = vim.fn.expand("<cword>")
	local new_word = replace_map[word]

	-- 如果是 LSP 枚举项
	if not new_word then
		local params = util.make_position_params(0, "utf-8")
		local items = get_lsp_items(params)

		if vim.tbl_isempty(items) then
			return
		end

		local index
		for i, value in ipairs(items) do
			if value.label == word then
				index = i
				break
			end
		end

		if not index then
			return
		end

		-- 切换到下一个枚举项
		index = index + 1
		if index > #items then
			index = 1
		end

		local next_item = items[index]

		vim.cmd("s/" .. word .. "/" .. next_item.label)
		return
	end

	-- 默认的切换逻辑
	local keys = new_word and ("ciw" .. new_word .. "<Esc>") or default_key
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

vim.keymap.set("n", "<C-a>", function()
	toggle_or_default("<C-a>")
end, { desc = "Increment number, toggle boolean or cycle enum" })

vim.keymap.set("n", "<C-x>", function()
	toggle_or_default("<C-x>")
end, { desc = "Decrement number, toggle boolean or cycle enum" })
