local M = {}

vim.api.nvim_set_hl(0, "FunctionRefFold", { fg = "#c678dd" }) -- 展开/折叠符号
vim.api.nvim_set_hl(0, "FunctionRefIcon", { fg = "#e5c07b", bold = true }) -- 节点图标
vim.api.nvim_set_hl(0, "FunctionRefMode", { fg = "#61afef" }) -- [OUTGOING] / [INCOMING]
vim.api.nvim_set_hl(0, "FunctionRefName", { fg = "#98c379" }) -- 函数名
vim.api.nvim_set_hl(0, "FunctionRefLocation", { fg = "#5c6370" }) -- 文件名:行号

-- === 常量与配置 ===
local DEFAULT_DEPTH = 3
local POSITION_ENCODING = "utf-16"
local BUFFER_NAME_PREFIX = "FunctionReferences://"
local STATE = { PENDING = 1, FETCHED = 2, ERROR = 3 }
local MODE = {
	OUTGOING = "outgoing", -- 当前函数调用了谁 (默认)
	INCOMING = "incoming", -- 谁调用了当前函数
}

-- 统一图标系统
local ICONS = {
	ROOT_INCOMING = "", -- 被调用模式根节点
	ROOT_OUTGOING = "", -- 调用模式根节点
	INCOMING = "", -- 被调用节点
	OUTGOING = "", -- 调用节点
	EXPANDED = "▾", -- 已展开
	COLLAPSED = "▸", -- 未展开
	LEAF = " ", -- 叶节点占位（一个空格）
}

-- === 模块内部状态 ===
local instances = {}
local next_instance_id = 0

-- === 核心工具函数 ===
local function safe_call(fn, ...)
	local status, result = pcall(fn, ...)
	if not status then
		vim.schedule(function()
			vim.notify("LSP CallTree Error: " .. tostring(result), vim.log.levels.DEBUG)
		end)
		return nil
	end
	return result
end

local function format_location(uri, line)
	return vim.fn.fnamemodify(uri, ":t") .. ":" .. (line + 1)
end

local function get_error_message(err)
	if not err then
		return "无结果"
	end
	if type(err) == "table" then
		return err.message or vim.inspect(err)
	end
	return tostring(err)
end

local function has_capability(bufnr, capability)
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	for _, client in ipairs(clients) do
		if client.server_capabilities[capability] then
			return true
		end
	end
	return false
end

local function create_tree_node(item)
	return {
		name = item.name,
		uri = item.uri,
		range = item.range,
		selectionRange = item.selectionRange,
		references = {},
		callers = {},
		display = item.name .. " [" .. format_location(item.uri, item.selectionRange.start.line) .. "]",
	}
end

local function setup_buffer(bufnr)
	local opts = {
		buftype = "nofile",
		bufhidden = "wipe",
		swapfile = false,
		filetype = "functionreferences",
		modifiable = false,
	}

	for opt, value in pairs(opts) do
		pcall(vim.api.nvim_set_option_value, opt, value, { buf = bufnr })
	end
end

local function setup_window(winid)
	local opts = {
		wrap = false,
		number = false,
		relativenumber = false,
		signcolumn = "no",
	}

	for opt, value in pairs(opts) do
		pcall(vim.api.nvim_set_option_value, opt, value, { win = winid })
	end
end

local function render_buffer_content(instance, lines)
	local bufnr = instance.refs_buf
	local ns = instance.ns

	local text_lines = {}
	local extmarks = {}

	for i, line in ipairs(lines) do
		local segments = line.text
		local full = ""
		local col = 0
		extmarks[i] = {}

		for _, seg in ipairs(segments) do
			full = full .. seg.text
			if seg.hl then
				table.insert(extmarks[i], {
					start_col = col,
					end_col = col + #seg.text,
					hl = seg.hl,
				})
			end
			col = col + #seg.text
		end

		text_lines[i] = full
	end

	-- 写入 buffer
	vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text_lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

	-- 清除旧高亮
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	-- 应用 extmarks
	for i, marks in pairs(extmarks) do
		for _, m in ipairs(marks) do
			vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, m.start_col, {
				end_col = m.end_col,
				hl_group = m.hl,
			})
		end
	end

	instance.line_data = lines
	pcall(vim.api.nvim_buf_set_var, bufnr, "line_data", lines)
	pcall(vim.api.nvim_buf_set_var, bufnr, "expanded_nodes", instance.expanded_nodes)
end

local function setup_buffer_keymaps(bufnr, instance_id)
	local keymaps = {
		{
			"n",
			"<CR>",
			function()
				M._toggle_node(instance_id)
			end,
		},
		{
			"n",
			"<tab>",
			function()
				M._switch_mode(instance_id)
			end,
		},
		{
			"n",
			"gd",
			function()
				M._goto_definition(instance_id)
			end,
		},
		{
			"n",
			"q",
			function()
				M._close_instance(instance_id)
			end,
		},
	}

	for _, km in ipairs(keymaps) do
		vim.api.nvim_buf_set_keymap(bufnr, km[1], km[2], "", {
			noremap = true,
			silent = true,
			callback = km[3],
		})
	end
end

local function get_line_data(instance, bufnr)
	local ok, buf_line_data = pcall(vim.api.nvim_buf_get_var, bufnr, "line_data")
	if ok and buf_line_data then
		return buf_line_data
	end
	return instance.line_data
end

local function handle_hierarchy_error(err, result, instance)
	if err or not result or vim.tbl_isempty(result) then
		local err_msg = get_error_message(err)
		vim.notify("无法准备调用层级数据: " .. err_msg, vim.log.levels.ERROR)
		instance:_cleanup()
		return false
	end
	return true
end

-- === 实例生命周期管理 ===
local function create_instance()
	next_instance_id = next_instance_id + 1
	local instance_id = next_instance_id

	local instance = {
		id = instance_id,
		state = STATE.PENDING,
		reference_tree = nil,
		incoming_tree = nil,
		pending_items = 0,
		depth = DEFAULT_DEPTH,
		current_item = nil,
		current_mode = MODE.OUTGOING,
		refs_buf = nil,
		refs_win = nil,
		ns = vim.api.nvim_create_namespace("function_references_" .. instance_id),
		line_data = {},
		expanded_nodes = {},
		incoming_data = {},
		_timer = nil,
		_cleaned = false,
		_cleanup = function(self)
			if self._cleaned then
				return
			end
			self._cleaned = true

			if self._timer then
				pcall(function()
					self._timer:close()
				end)
				self._timer = nil
			end
			instances[self.id] = nil
		end,
	}

	instances[instance_id] = instance
	return instance
end

-- === 核心数据获取与处理 ===
local function process_item_calls(instance, item, current_depth, parent_node)
	if current_depth > instance.depth then
		instance.pending_items = instance.pending_items - 1
		if instance.pending_items == 0 then
			instance.state = STATE.FETCHED
			safe_call(M._display_ui, instance)
		end
		return
	end

	-- 避免自引用导致无限循环
	local is_exact_self_ref = (
		item.name == parent_node.name
		and item.uri == parent_node.uri
		and item.selectionRange.start.line == parent_node.selectionRange.start.line
	)

	local current_node = nil
	if not is_exact_self_ref then
		current_node = parent_node.references[item.name]
		if not current_node then
			current_node = create_tree_node(item)
			parent_node.references[item.name] = current_node
		end
	end

	local params = { item = item }

	vim.lsp.buf_request(0, "callHierarchy/outgoingCalls", params, function(err, result)
		if err then
			vim.notify("LSP Call Error: " .. get_error_message(err), vim.log.levels.WARN)
		end

		if not err and result and not vim.tbl_isempty(result) then
			for _, call in ipairs(result) do
				local target = call.to
				local next_parent = current_node or parent_node

				instance.pending_items = instance.pending_items + 1
				vim.defer_fn(function()
					process_item_calls(instance, target, current_depth + 1, next_parent)
				end, 10)
			end
		end

		instance.pending_items = instance.pending_items - 1
		if instance.pending_items == 0 then
			instance.state = STATE.FETCHED
			safe_call(M._display_ui, instance)
		end
	end)
end

local function process_item_callers(instance, item, current_depth, parent_node)
	if current_depth > instance.depth then
		instance.pending_items = instance.pending_items - 1
		if instance.pending_items == 0 then
			instance.state = STATE.FETCHED
			safe_call(M._display_ui, instance)
		end
		return
	end

	-- 创建节点ID用于去重
	local node_id = item.name .. ":" .. item.uri .. ":" .. item.selectionRange.start.line

	local current_node = nil

	-- 检查是否已处理过此节点（跨分支重复）
	if not instance.incoming_data[node_id] then
		current_node = {
			name = item.name,
			uri = item.uri,
			range = item.range,
			selectionRange = item.selectionRange,
			callers = {},
			depth = current_depth,
			id = node_id,
		}
		instance.incoming_data[node_id] = current_node
	else
		current_node = instance.incoming_data[node_id]
	end

	-- 链接到父节点
	if parent_node and parent_node.callers then
		parent_node.callers[node_id] = current_node
	end

	local params = { item = item }

	vim.lsp.buf_request(0, "callHierarchy/incomingCalls", params, function(err, result)
		if err then
			vim.notify("LSP Incoming Calls Error: " .. get_error_message(err), vim.log.levels.WARN)
		end

		if not err and result and not vim.tbl_isempty(result) then
			for _, call in ipairs(result) do
				local caller = call.from -- 注意：incomingCalls 返回的是 call.from

				instance.pending_items = instance.pending_items + 1
				vim.defer_fn(function()
					process_item_callers(instance, caller, current_depth + 1, current_node)
				end, 10)
			end
		end

		instance.pending_items = instance.pending_items - 1
		if instance.pending_items == 0 then
			instance.state = STATE.FETCHED
			safe_call(M._display_ui, instance)
		end
	end)
end

-- === UI 渲染层 ===
function M._build_reference_lines(node, lines, indent, expanded_nodes, mode, is_root)
	indent = indent or 0
	lines = lines or {}
	expanded_nodes = expanded_nodes or {}
	mode = mode or MODE.OUTGOING

	-- 数据源
	local data_source = (mode == MODE.INCOMING) and node.callers or node.references

	-- 图标
	local icon = ""
	if is_root then
		icon = (mode == MODE.INCOMING) and ICONS.ROOT_INCOMING or ICONS.ROOT_OUTGOING
	else
		icon = (mode == MODE.INCOMING) and ICONS.INCOMING or ICONS.OUTGOING
	end

	local has_children = data_source and next(data_source) ~= nil
	local node_key = node.id or (node.name .. ":" .. node.uri)
	local expanded = expanded_nodes[node_key]

	-- 缩进 + 展开符
	local prefix = string.rep("  ", indent)
	local fold_icon = has_children and (expanded and ICONS.EXPANDED or ICONS.COLLAPSED) or ICONS.LEAF

	-- 位置
	local location = ""
	if node.uri then
		location = " [" .. format_location(node.uri, node.selectionRange.start.line) .. "]"
	end

	-- 模式标签
	local mode_indicator = is_root and (" [" .. mode:upper() .. "] ") or " "

	-- ✅ 结构化 segments
	local segments = {
		{ text = prefix },
		{ text = fold_icon, hl = "FunctionRefFold" },
		{ text = icon, hl = "FunctionRefIcon" },
		{ text = mode_indicator, hl = "FunctionRefMode" },
		{ text = node.name, hl = "FunctionRefName" },
		{ text = location, hl = "FunctionRefLocation" },
	}

	table.insert(lines, {
		text = segments,
		node = node,
		indent = indent,
		has_refs = has_children,
		mode = mode,
		is_root = is_root or false,
		icon_char = icon,
	})

	-- 递归
	if expanded and has_children then
		for _, child in pairs(data_source) do
			M._build_reference_lines(child, lines, indent + 1, expanded_nodes, mode, false)
		end
	end

	return lines
end

function M._display_ui(instance)
	if not instance.reference_tree then
		vim.notify("No function data found", vim.log.levels.INFO)
		instance:_cleanup()
		return
	end

	-- 创建或重用缓冲区
	if not instance.refs_buf or not vim.api.nvim_buf_is_valid(instance.refs_buf) then
		instance.refs_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(instance.refs_buf, BUFFER_NAME_PREFIX .. instance.id)
		setup_buffer(instance.refs_buf)
	end

	-- 获取或创建窗口
	local win_width = math.floor(vim.api.nvim_get_option_value("columns", { scope = "global" }) * 0.4)

	if not instance.refs_win or not vim.api.nvim_win_is_valid(instance.refs_win) then
		vim.cmd("vsplit")
		instance.refs_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(instance.refs_win, instance.refs_buf)
		vim.api.nvim_win_set_width(instance.refs_win, win_width)
		setup_window(instance.refs_win)
	end

	-- 构建并渲染内容
	local root_node_key = instance.current_item.name
		.. ":"
		.. instance.current_item.uri
		.. ":"
		.. instance.current_item.selectionRange.start.line

	-- 确保根节点展开
	if not instance.expanded_nodes[root_node_key] then
		instance.expanded_nodes[root_node_key] = true
	end

	-- 选择要显示的根节点
	local display_root
	if instance.current_mode == MODE.INCOMING then
		display_root = instance.incoming_data[root_node_key] or instance.reference_tree
	else
		display_root = instance.reference_tree
	end

	local lines = M._build_reference_lines(display_root, {}, 0, instance.expanded_nodes, instance.current_mode, true)

	render_buffer_content(instance, lines)

	setup_buffer_keymaps(instance.refs_buf, instance.id)

	-- 设置状态行
	pcall(function()
		local mode_text = instance.current_mode == MODE.OUTGOING and "OUTGOING" or "INCOMING"
		vim.cmd(
			"setlocal statusline=CALL-TREE["
				.. mode_text
				.. "]:\\ "
				.. instance.reference_tree.name:gsub("\\", "\\\\"):gsub(" ", "\\ ")
		)
	end)
end

-- === 模式切换功能 ===
function M._switch_mode(instance_id)
	local instance = instances[instance_id]
	if not instance then
		return
	end

	-- 切换模式
	if instance.current_mode == MODE.OUTGOING then
		instance.current_mode = MODE.INCOMING
	else
		instance.current_mode = MODE.OUTGOING
	end

	-- 如果切换到INCOMING模式且尚未加载数据，则发起请求
	local root_node_id = instance.current_item.name
		.. ":"
		.. instance.current_item.uri
		.. ":"
		.. instance.current_item.selectionRange.start.line

	if instance.current_mode == MODE.INCOMING and not instance.incoming_data[root_node_id] then
		-- 创建incoming树的根节点
		instance.incoming_data[root_node_id] = {
			name = instance.current_item.name,
			uri = instance.current_item.uri,
			range = instance.current_item.range,
			selectionRange = instance.current_item.selectionRange,
			callers = {},
			id = root_node_id,
			is_root = true,
		}

		instance.pending_items = 1
		instance.state = STATE.PENDING
		process_item_callers(instance, instance.current_item, 1, instance.incoming_data[root_node_id])
	else
		-- 直接刷新UI
		safe_call(M._display_ui, instance)
	end

	vim.notify("切换到模式: " .. instance.current_mode:upper(), vim.log.levels.INFO)
end

-- === 公共 API ===
function M.open_call_tree(depth)
	depth = depth or DEFAULT_DEPTH

	if not has_capability(0, "callHierarchyProvider") then
		vim.notify("当前LSP服务器不支持调用层级功能", vim.log.levels.WARN)
		return
	end

	local instance = create_instance()
	instance.depth = depth

	local params = vim.lsp.util.make_position_params(0, POSITION_ENCODING)

	vim.lsp.buf_request(0, "textDocument/prepareCallHierarchy", params, function(err, result)
		if not handle_hierarchy_error(err, result, instance) then
			return
		end

		local item = result[1]
		instance.current_item = item
		instance.reference_tree = create_tree_node(item)

		-- 为incoming模式预创建根节点记录
		local root_node_id = item.name .. ":" .. item.uri .. ":" .. item.selectionRange.start.line
		instance.incoming_data[root_node_id] = {
			name = item.name,
			uri = item.uri,
			range = item.range,
			selectionRange = item.selectionRange,
			callers = {},
			id = root_node_id,
			is_root = true,
		}

		instance.pending_items = 1
		instance.state = STATE.PENDING

		-- 设置超时保护 (15秒)
		instance._timer = vim.defer_fn(function()
			if instances[instance.id] and instance.state == STATE.PENDING then
				vim.notify("调用树分析超时，可能项目过大或LSP服务器响应慢", vim.log.levels.WARN)
				instance:_cleanup()
			end
		end, 15000)

		vim.defer_fn(function()
			process_item_calls(instance, item, 1, instance.reference_tree)
		end, 0)
	end)
end

-- === 内部API ===
function M._toggle_node(instance_id)
	local instance = instances[instance_id]
	if not instance then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	if bufnr ~= instance.refs_buf then
		return
	end

	local line_nr = vim.api.nvim_win_get_cursor(0)[1]
	local line_data = get_line_data(instance, bufnr)

	if not line_data or not line_data[line_nr] then
		return
	end

	local item = line_data[line_nr]
	if not item.has_refs then
		M._goto_definition(instance_id)
		return
	end

	local expanded_nodes
	local ok, buf_expanded_nodes = pcall(vim.api.nvim_buf_get_var, bufnr, "expanded_nodes")
	if ok and buf_expanded_nodes then
		expanded_nodes = buf_expanded_nodes
	else
		expanded_nodes = instance.expanded_nodes or {}
	end

	local node_id = item.node.id or (item.node.name .. ":" .. item.node.uri)
	expanded_nodes[node_id] = not expanded_nodes[node_id]

	pcall(vim.api.nvim_buf_set_var, bufnr, "expanded_nodes", expanded_nodes)
	instance.expanded_nodes = expanded_nodes

	-- 重绘
	local root_node_id = instance.current_item.name
		.. ":"
		.. instance.current_item.uri
		.. ":"
		.. instance.current_item.selectionRange.start.line
	local display_root
	if instance.current_mode == MODE.INCOMING then
		display_root = instance.incoming_data[root_node_id] or instance.reference_tree
	else
		display_root = instance.reference_tree
	end

	local lines = M._build_reference_lines(display_root, {}, 0, expanded_nodes, instance.current_mode, true)

	render_buffer_content(instance, lines)
	vim.api.nvim_win_set_cursor(0, { line_nr, 0 })
end

function M._goto_definition(instance_id)
	local instance = instances[instance_id]
	if not instance then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	if bufnr ~= instance.refs_buf then
		return
	end

	local line_nr = vim.api.nvim_win_get_cursor(0)[1]
	local line_data = get_line_data(instance, bufnr)

	if not line_data or not line_data[line_nr] then
		return
	end

	local item = line_data[line_nr]
	local node = item.node

	if node and node.uri and node.selectionRange then
		local filename = vim.uri_to_fname(node.uri)

		-- 创建新窗口来打开文件，保持引用窗口可见
		vim.cmd("vsplit")
		local new_win = vim.api.nvim_get_current_win()

		-- 在新窗口中打开文件并跳转到对应位置
		local jump_cmd = "edit +" .. (node.selectionRange.start.line + 1) .. " " .. vim.fn.fnameescape(filename)
		vim.cmd(jump_cmd)

		-- 定位光标到具体位置
		if node.selectionRange.start.character then
			vim.api.nvim_win_set_cursor(
				new_win,
				{ node.selectionRange.start.line + 1, node.selectionRange.start.character }
			)
		end
	end
end

function M._close_instance(instance_id)
	local instance = instances[instance_id]
	if not instance then
		return
	end

	if instance.refs_win and vim.api.nvim_win_is_valid(instance.refs_win) then
		vim.api.nvim_win_close(instance.refs_win, true)
	end

	if instance.refs_buf and vim.api.nvim_buf_is_valid(instance.refs_buf) then
		vim.api.nvim_buf_delete(instance.refs_buf, { force = true })
	end

	instance:_cleanup()
end

return M
