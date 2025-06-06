local quickfix = {}

-- 缓存常用值
local PATH_SEP = string.sub(package.config, 1, 1)
local NS_NAME = "quickfix_decorations"

-- 路径处理工具
local path_utils = {}
function path_utils.shorten(path)
	local parts = vim.split(path, PATH_SEP, { trimempty = true })
	for i = 2, #parts - 1 do
		if not string.match(parts[i], "^%.") then
			parts[i] = string.sub(parts[i], 1, 1)
		end
	end
	return table.concat(parts, PATH_SEP)
end

-- 文本处理工具
local text_utils = {}
function text_utils.range_text(a, b)
	return a == b and tostring(a) or (tostring(a) .. "-" .. tostring(b))
end

function text_utils.center(text, width)
	local text_width = vim.fn.strdisplaywidth(text)
	local padding = width - text_width
	if padding <= 0 then
		return text
	end

	local left = math.floor(padding / 2)
	local right = math.ceil(padding / 2)
	return string.rep(" ", left) .. text .. string.rep(" ", right)
end

-- 列表处理工具
local list_utils = {}
function list_utils.process_items(items, start_idx, end_idx)
	local infos, path_width, loc_width = {}, 0, 0

	for i = start_idx, end_idx do
		local item = items[i]
		if not item.valid or item.valid == 1 then
			local bufname = vim.api.nvim_buf_get_name(item.bufnr)
			local path = path_utils.shorten(vim.fn.fnamemodify(bufname, ":~:."))
			local rows = text_utils.range_text(item.lnum, item.end_lnum or item.lnum)
			local cols = text_utils.range_text(item.col, item.end_col or item.col)
			local location = rows .. " col " .. cols

			path_width = math.max(path_width, vim.fn.strdisplaywidth(path))
			loc_width = math.max(loc_width, vim.fn.strdisplaywidth(location))

			table.insert(infos, {
				path = path,
				location = location,
				text = item.text,
			})
		end
	end

	return infos, path_width, loc_width
end

function list_utils.build_lines(infos, path_width, loc_width)
	local lines = {}
	for _, info in ipairs(infos) do
		local line = string.format(" %-" .. path_width .. "s", info.path)
		line = line .. " | " .. text_utils.center(info.location, loc_width) .. " |"
		if info.text then
			line = line .. " " .. info.text
		end
		table.insert(lines, line)
	end
	return lines
end

-- 位置列表处理
function quickfix.loc_text(data)
	local items = vim.fn.getloclist(data.winid, { id = data.id, items = 0 }).items
	local infos, path_width, loc_width = list_utils.process_items(items, data.start_idx, data.end_idx)
	return list_utils.build_lines(infos, path_width, loc_width)
end

-- 快速修复列表处理
function quickfix.qf_text(data)
	local items = vim.fn.getqflist({ id = data.id, items = 0 }).items
	local infos, path_width, loc_width = list_utils.process_items(items, data.start_idx, data.end_idx)
	return list_utils.build_lines(infos, path_width, loc_width)
end

-- 主文本展示
function quickfix.text(data)
	return data.quickfix == 1 and quickfix.qf_text(data) or quickfix.loc_text(data)
end

-- 装饰器回调
local decor_callbacks = {
	qf_filename = function(buf, ns, node, injection_lines)
		local text = vim.treesitter.get_node_text(node, buf, {})
		local whitespaces = string.match(text, "^%s*")
		local range = { node:range() }

		if package.loaded["icons"] then
			local icon = package.loaded["icons"].get(vim.fn.fnamemodify(text, ":e"), {
				"@comment",
				"DiagnosticError",
				"@constant",
				"DiagnosticWarn",
				"DiagnosticOk",
				"@function",
				"@property",
			})

			vim.api.nvim_buf_set_extmark(buf, ns, range[1], range[2] + #whitespaces, {
				end_col = range[4],
				virt_text_pos = "inline",
				virt_text = { { icon.icon, icon.hl } },
				hl_group = icon.hl,
			})
		end
	end,

	qf_separator = function(buf, ns, node, injection_lines)
		local text = vim.treesitter.get_node_text(node, buf, {})
		local whitespaces = string.match(text, "^%s*")
		local range = { node:range() }
		local line_count = vim.api.nvim_buf_line_count(buf)
		local char = "│"

		if not node:parent():next_sibling() and not node:parent():prev_sibling() then
			char = "◆"
		elseif range[1] == 0 then
			char = "╷"
		elseif range[1] == line_count - 1 then
			char = "╵"
		end

		vim.api.nvim_buf_set_extmark(buf, ns, range[1], range[2] + #whitespaces, {
			end_col = range[4],
			hl_mode = "combine",
			virt_text_pos = "overlay",
			virt_text = { { char } },
		})
	end,

	qf_content = function(buf, ns, node, injection_lines, list_type)
		local text = vim.treesitter.get_node_text(node, buf, {})
		local whitespaces = string.match(text, "^%s*")
		local range = { node:range() }
		local icons = require("utils.utils").icons
		local kinds = {
			default = { "󱈤 ", "@function" },
			loc = { " ", "@conditional" },
			w = { icons.diagnostic.WARN, "DiagnosticWarn" },
			e = { icons.diagnostic.ERROR, "DiagnosticError" },
			i = { icons.diagnostic.INFO, "DiagnosticInfo" },
			n = { icons.diagnostic.HINT, "DiagnosticHint" },
		}
		local virt_text = kinds.default

		if list_type == "location" then
			virt_text = kinds.loc
		else
			local qflist = vim.fn.getqflist()
			if qflist[range[1] + 1] then
				local item = qflist[range[1] + 1]
				local item_type = string.lower(item.type or "")
				virt_text = kinds[item_type] or kinds.default

				if item.text and item.text ~= "" and text ~= " " .. item.text then
					vim.api.nvim_buf_set_extmark(buf, ns, range[1], range[2], {
						virt_lines = { { { " ╰╴", "@comment" }, { item.text, virt_text[2] } } },
					})
				elseif item.text and item.text ~= "" then
					virt_text = { "󰵅 ", virt_text[2] }
				end
			end
		end

		local has_space = #whitespaces > 0
		vim.api.nvim_buf_set_extmark(buf, ns, range[1], range[2] + (has_space and 1 or 0), {
			virt_text_pos = "inline",
			virt_text = { { has_space and "" or " " }, virt_text },
		})

		-- 修复：使用 vim.list_contains 替代不存在的 vim.tbl_contains
		local found = false
		for _, line_num in ipairs(injection_lines) do
			if line_num == range[1] then
				found = true
				break
			end
		end

		if not found then
			vim.api.nvim_buf_set_extmark(buf, ns, range[1], range[2] + #whitespaces, {
				end_col = range[4],
				hl_group = "@comment",
			})
		end
	end,
}

-- 添加装饰
function quickfix.add_decor(name, node, injection_lines, list_type)
	if decor_callbacks[name] then
		pcall(decor_callbacks[name], quickfix.buffer, quickfix.ns, node, injection_lines, list_type)
	end
end

-- 装饰修复列表
function quickfix.decorate(from, to)
	if not quickfix.buffer or not vim.api.nvim_buf_is_valid(quickfix.buffer) then
		return
	end

	vim.api.nvim_buf_clear_namespace(quickfix.buffer, quickfix.ns, 0, -1)

	local parser = vim.treesitter.get_parser(quickfix.buffer, "qf", { error = false })
	if not parser then
		return
	end

	local tstree = parser:parse(true)[1]
	if not tstree then
		return
	end

	local injection_lines = {}
	parser:for_each_tree(function(tree)
		if tree ~= tstree then
			table.insert(injection_lines, tree:root():range())
		end
	end)

	-- 修复查询字符串语法错误：添加缺失的闭合括号
	local query = vim.treesitter.query.parse(
		"qf",
		[[
        (filename) @qf_filename
        [ "|" ] @qf_separator
        (code_block (content) @qf_content)
    ]]
	)

	for id, node in query:iter_captures(tstree:root(), quickfix.buffer, from, to) do
		quickfix.add_decor(query.captures[id], node, injection_lines, quickfix.list)
	end
end

-- 初始化
function quickfix.setup()
	quickfix.ns = vim.api.nvim_create_namespace(NS_NAME)
	vim.o.quickfixtextfunc = "v:lua.require'config.quickfixtext'.text"

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "qf",
		callback = function(event)
			quickfix.buffer = event.buf
			local win = vim.fn.win_findbuf(event.buf)[1]
			if not win then
				return
			end

			-- 判断当前 quickfix 窗口是 location list 还是 quickfix list
			local winfo = vim.fn.getwininfo(win)[1]
			quickfix.list = winfo.loclist and "location" or "quickfix"

			vim.wo[win].conceallevel = 3
			vim.wo[win].concealcursor = "nc"
			vim.wo[win].number = false
			vim.wo[win].relativenumber = false
			vim.wo[win].numberwidth = 1
			vim.wo[win].signcolumn = "no"
			vim.wo[win].foldcolumn = "0"

			quickfix.decorate(0, vim.api.nvim_win_get_height(win))
		end,
	})

	vim.api.nvim_create_autocmd("QuickfixCmdPre", {
		callback = function(event)
			quickfix.last_command = event.match
		end,
	})

	vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
		callback = function()
			local buf = vim.api.nvim_get_current_buf()
			if buf ~= quickfix.buffer then
				return
			end

			-- 确保缓冲区可修改
			if vim.bo.modifiable then
				local cursor = vim.api.nvim_win_get_cursor(0)
				local total_lines = vim.api.nvim_buf_line_count(buf)
				local start = math.max(0, cursor[1] - 20)
				local end_line = math.min(total_lines, cursor[1] + 20)

				quickfix.decorate(start, end_line)
			end
		end,
	})

	vim.api.nvim_create_user_command("QfToggleDecors", function()
		quickfix.should_decorate = not quickfix.should_decorate
		quickfix.decorate(0, -1)
	end, { desc = "Toggle quickfix decorations" })
end

return quickfix
