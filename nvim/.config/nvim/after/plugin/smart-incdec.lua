-- 替换规则映射表
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

-- LSP配置
local lsp = vim.lsp
local ms = vim.lsp.protocol.Methods
local util = vim.lsp.util

-- 处理替换逻辑
local function handle_replacement(word)
	local new_word = replace_map[word]
	if new_word then
		local keys = "ciw" .. new_word .. "<Esc>"
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
		return true
	end
	return false
end

-- 处理数字增减
local function handle_number(word, operation)
	if word:match("^%d+$") then
		local num = tonumber(word)
		local new_num = operation == "increment" and num + 1 or num - 1
		vim.cmd("normal! ciw" .. new_num)
		return true
	end
	return false
end

-- 获取 LSP 枚举项
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

-- 处理枚举切换
local function handle_enum(word)
	local params = util.make_position_params(0, "utf-8")
	local items = get_lsp_items(params)

	if vim.tbl_isempty(items) then
		return false
	end

	-- 查找当前单词的枚举索引
	local index
	for i, value in ipairs(items) do
		if value.label == word then
			index = i
			break
		end
	end

	if not index then
		return false
	end

	-- 切换到下一个枚举项
	index = (index % #items) + 1
	local next_item = items[index]
	vim.cmd("s/" .. word .. "/" .. next_item.label)
	return true
end

-- 执行操作
local function toggle_or_default(default_key)
	local word = vim.fn.expand("<cword>")

	-- 1. 优先处理替换表
	if handle_replacement(word) then
		return
	end

	-- 2. 其次处理数字增减
	if handle_number(word, default_key == "<C-a>" and "increment" or "decrement") then
		return
	end

	-- 3. 最后处理枚举项切换
	if not handle_enum(word) then
		-- 如果都没有匹配到任何操作，执行默认的键映射
		local keys = default_key
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
	end
end

-- 设置按键映射
vim.keymap.set("n", "<C-a>", function()
	toggle_or_default("<C-a>")
end, { desc = "Increment number, toggle boolean or cycle enum" })

vim.keymap.set("n", "<C-x>", function()
	toggle_or_default("<C-x>")
end, { desc = "Decrement number, toggle boolean or cycle enum" })
