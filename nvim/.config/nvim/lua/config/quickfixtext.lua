local quickfix = {}

-- 缓存常用值
local PATH_SEP = string.sub(package.config, 1, 1)
local NS_NAME = "quickfix_decorations"

-- 路径处理工具
local function shorten_path(path)
	if path == "" then
		return ""
	end
	local parts = vim.split(path, PATH_SEP, { trimempty = true })
	for i = 2, #parts - 1 do
		if not string.match(parts[i], "^%.") then
			parts[i] = string.sub(parts[i], 1, 1)
		end
	end
	return table.concat(parts, PATH_SEP)
end

-- 文本处理工具
local function range_text(a, b)
	return a == b and tostring(a) or (tostring(a) .. "-" .. tostring(b))
end

local function center(text, width)
	local text_width = vim.fn.strdisplaywidth(text)
	if text_width >= width then
		return text
	end

	local left = math.floor((width - text_width) / 2)
	local right = width - text_width - left
	return string.rep(" ", left) .. text .. string.rep(" ", right)
end

-- 列表处理工具
local function process_items(items, start_idx, end_idx)
	local infos, path_width, loc_width = {}, 0, 0
	local valid_items = {}

	-- 先收集有效项，减少重复计算
	for i = start_idx, end_idx do
		local item = items[i]
		if item and (not item.valid or item.valid == 1) then
			table.insert(valid_items, item)
		end
	end

	for _, item in ipairs(valid_items) do
		local bufname = vim.api.nvim_buf_get_name(item.bufnr)
		local path = shorten_path(vim.fn.fnamemodify(bufname, ":~:."))
		local rows = range_text(item.lnum, item.end_lnum or item.lnum)
		local cols = range_text(item.col, item.end_col or item.col)
		local location = rows .. " col " .. cols

		path_width = math.max(path_width, vim.fn.strdisplaywidth(path))
		loc_width = math.max(loc_width, vim.fn.strdisplaywidth(location))

		table.insert(infos, {
			path = path,
			location = location,
			text = item.text,
		})
	end

	return infos, path_width, loc_width
end

local function build_lines(infos, path_width, loc_width)
	local lines = {}
	for _, info in ipairs(infos) do
		local line = string.format(" %-" .. path_width .. "s", info.path)
		line = line .. " | " .. center(info.location, loc_width) .. " |"
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
	local infos, path_width, loc_width = process_items(items, data.start_idx, data.end_idx)
	return build_lines(infos, path_width, loc_width)
end

-- 快速修复列表处理
function quickfix.qf_text(data)
	local items = vim.fn.getqflist({ id = data.id, items = 0 }).items
	local infos, path_width, loc_width = process_items(items, data.start_idx, data.end_idx)
	return build_lines(infos, path_width, loc_width)
end

-- 主文本展示
function quickfix.text(data)
	return data.quickfix == 1 and quickfix.qf_text(data) or quickfix.loc_text(data)
end

-- 装饰器回调
local decor_callbacks = {
	qf_filename = function(buf, ns, node, injection_set)
		local text = vim.treesitter.get_node_text(node, buf, {})
		local whitespaces = string.match(text, "^%s*") or ""
		local srow, scol, _, ecol = node:range()

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

			vim.api.nvim_buf_set_extmark(buf, ns, srow, scol + #whitespaces, {
				end_col = ecol,
				virt_text_pos = "inline",
				virt_text = { { icon.icon, icon.hl } },
				hl_group = icon.hl,
			})
		end
	end,

	qf_separator = function(buf, ns, node, injection_set)
		local text = vim.treesitter.get_node_text(node, buf, {})
		local whitespaces = string.match(text, "^%s*") or ""
		local srow, scol, _, ecol = node:range()
		local line_count = vim.api.nvim_buf_line_count(buf)
		local char = "│"

		local parent = node:parent()
		if parent then
			if not parent:next_sibling() and not parent:prev_sibling() then
				char = "◆"
			elseif srow == 0 then
				char = "╷"
			elseif srow == line_count - 1 then
				char = "╵"
			end
		end

		vim.api.nvim_buf_set_extmark(buf, ns, srow, scol + #whitespaces, {
			end_col = ecol,
			hl_mode = "combine",
			virt_text_pos = "overlay",
			virt_text = { { char } },
		})
	end,

	qf_content = function(buf, ns, node, injection_set, list_type)
		local text = vim.treesitter.get_node_text(node, buf, {})
		local whitespaces = string.match(text, "^%s*") or ""
		local srow, scol, _, ecol = node:range()

		-- 修复图标加载问题
		local diagnostic_icons = {
			WARN = " ",
			ERROR = "󰅙 ",
			INFO = "󰀨 ",
			HINT = "󰁨 ",
		}

		-- 尝试加载自定义图标
		local custom_icons_ok, custom_icons = pcall(require, "utils.utils")
		if custom_icons_ok and custom_icons.icons and custom_icons.icons.diagnostic then
			diagnostic_icons = custom_icons.icons.diagnostic
		end

		local kinds = {
			default = { "󱈤 ", "@function" },
			loc = { " ", "@conditional" },
			w = { diagnostic_icons.WARN, "DiagnosticWarn" },
			e = { diagnostic_icons.ERROR, "DiagnosticError" },
			i = { diagnostic_icons.INFO, "DiagnosticInfo" },
			n = { diagnostic_icons.HINT, "DiagnosticHint" },
		}
		local virt_text = kinds.default

		if list_type == "location" then
			virt_text = kinds.loc
		else
			local qflist = vim.fn.getqflist()
			if qflist[srow + 1] then
				local item = qflist[srow + 1]
				local item_type = string.lower(item.type or "")
				virt_text = kinds[item_type] or kinds.default

				if item.text and item.text ~= "" and text ~= " " .. item.text then
					vim.api.nvim_buf_set_extmark(buf, ns, srow, scol, {
						virt_lines = { { { " ╰╴", "@comment" }, { item.text, virt_text[2] } } },
					})
				elseif item.text and item.text ~= "" then
					virt_text = { "󰵅 ", virt_text[2] }
				end
			end
		end

		local has_space = #whitespaces > 0
		vim.api.nvim_buf_set_extmark(buf, ns, srow, scol + (has_space and 1 or 0), {
			virt_text_pos = "inline",
			virt_text = { { has_space and "" or " " }, virt_text },
		})

		-- 使用集合进行快速查找
		if not injection_set[srow] then
			vim.api.nvim_buf_set_extmark(buf, ns, srow, scol + #whitespaces, {
				end_col = ecol,
				hl_group = "@comment",
			})
		end
	end,
}

-- 缓存Treesitter查询
local query_cache = nil
local function get_query()
	if not query_cache then
		query_cache = vim.treesitter.query.parse(
			"qf",
			[[
            (filename) @qf_filename
            [ "|" ] @qf_separator
            (code_block (content) @qf_content)
        ]]
		)
	end
	return query_cache
end

-- 添加装饰
local function add_decor(name, node, injection_set, list_type)
	if decor_callbacks[name] then
		pcall(decor_callbacks[name], quickfix.buffer, quickfix.ns, node, injection_set, list_type)
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

	-- 使用集合代替数组
	local injection_set = {}
	parser:for_each_tree(function(tree)
		if tree ~= tstree then
			injection_set[tree:root():range()] = true
		end
	end)

	local query = get_query()
	for id, node in query:iter_captures(tstree:root(), quickfix.buffer, from, to) do
		add_decor(query.captures[id], node, injection_set, quickfix.list)
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
			local wins = vim.fn.win_findbuf(event.buf)
			if #wins == 0 then
				return
			end

			local win = wins[1]
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

			-- 只在可修改时更新
			if vim.bo[buf].modifiable then
				local cursor = vim.api.nvim_win_get_cursor(0)
				local total_lines = vim.api.nvim_buf_line_count(buf)
				local start = math.max(0, cursor[1] - 1 - 20) -- 减1转换为0-based索引
				local end_line = math.min(total_lines - 1, cursor[1] - 1 + 20)

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
