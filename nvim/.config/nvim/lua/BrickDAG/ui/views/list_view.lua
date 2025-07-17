local M = {}

-- 判断一个table是否为数组（纯列表）
local function is_array(t)
	if type(t) ~= "table" then
		return false
	end
	for k in pairs(t) do
		if type(k) ~= "number" then
			return false
		end
	end
	return true
end

function M.render(buf, data)
	local items = data.items or {}
	local selected_index = data.selected_index or 1
	local layer_type = data.layer_type or "unknown"

	local lines = {}
	local highlights = {}

	-- 获取显示文本
	local function get_display_text(item)
		if item.name then
			return item.name
		elseif type(item.value) == "string" or type(item.value) == "number" then
			return tostring(item.value)
		else
			return vim.inspect(item.value)
		end
	end

	-- 获取图标和指示器（适配核心积木类型）
	local function get_icon_and_indicator(item)
		local icon = "○" -- 默认图标
		local indicator = ""

		-- 根任务
		if layer_type == "task_list" then
			icon = "󰄾" -- 任务图标（齿轮）

			-- 根据任务类型添加指示器
			if item.type == "frame" then
				indicator = " [F]" -- 框架任务指示器
			else
				indicator = " [B]" -- 基础任务指示器
			end

			if item.deps and #item.deps > 0 then
				indicator = indicator .. " [←]" -- 依赖指示器
			end

		-- 积木框架
		elseif layer_type == "frame_brick" then
			if item.type == "base_brick" then
				-- 基础积木显示为参数图标
				icon = "" -- 参数图标 (nf-cod-symbol_parameter)
			elseif item.type == "task_list" then
				-- 依赖任务
				icon = "" -- 链接图标 (nf-fa-chain)
				indicator = " [←]"
			end

		-- 基础积木
		elseif layer_type == "base_brick" then
			if type(item.value) == "table" then
				if is_array(item.value) then
					icon = "󰝰" -- 数组图标 (nf-md-format_list_bulleted)
				else
					icon = "󰯅" -- 字典图标 (nf-md-code_brackets)
				end
			else
				icon = "" -- 简单值图标 (nf-fa-plus_square_o)
			end
		end

		return icon, indicator
	end

	-- 渲染项目
	for i, item in ipairs(items) do
		local prefix = (i == selected_index) and "> " or "  "
		local icon, indicator = get_icon_and_indicator(item)
		local text = get_display_text(item)

		table.insert(lines, prefix .. icon .. " " .. text .. indicator)

		if i == selected_index then
			table.insert(highlights, { line = i - 1, hl = "Visual" })
		end
	end

	if #lines == 0 then
		table.insert(lines, "> 无内容")
	end

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	for _, hl in ipairs(highlights) do
		vim.api.nvim_buf_add_highlight(buf, -1, hl.hl, hl.line, 0, -1)
	end

	vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

return M
