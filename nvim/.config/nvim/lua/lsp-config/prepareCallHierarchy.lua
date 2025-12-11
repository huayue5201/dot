local M = {}

-- === 常量与配置 ===
local DEFAULT_DEPTH = 3
local POSITION_ENCODING = "utf-16"
local BUFFER_NAME_PREFIX = "FunctionReferences://"
local STATE = { PENDING = 1, FETCHED = 2, ERROR = 3 }

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

local function apply_highlights(bufnr, ns, lines)
	for i, line in ipairs(lines) do
		local icon_start = line.text:find("󰅲") or line.text:find("⭐")
		if icon_start then
			vim.api.nvim_buf_add_highlight(bufnr, ns, "Special", i - 1, icon_start - 1, icon_start)
		end

		local name_start = line.text:find(line.node.name)
		if name_start then
			vim.api.nvim_buf_add_highlight(
				bufnr,
				ns,
				"Function",
				i - 1,
				name_start - 1,
				name_start + #line.node.name - 1
			)
		end

		local loc_start = line.text:find(" %[")
		if loc_start then
			vim.api.nvim_buf_add_highlight(bufnr, ns, "Comment", i - 1, loc_start - 1, -1)
		end
	end
end

local function render_buffer_content(instance, lines)
	local text_lines = {}
	for _, line in ipairs(lines) do
		table.insert(text_lines, line.text)
	end

	vim.api.nvim_set_option_value("modifiable", true, { buf = instance.refs_buf })
	vim.api.nvim_buf_set_lines(instance.refs_buf, 0, -1, false, text_lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = instance.refs_buf })

	instance.line_data = lines
	pcall(vim.api.nvim_buf_set_var, instance.refs_buf, "line_data", lines)
	pcall(vim.api.nvim_buf_set_var, instance.refs_buf, "expanded_nodes", instance.expanded_nodes)

	vim.api.nvim_buf_clear_namespace(instance.refs_buf, instance.ns, 0, -1)
	apply_highlights(instance.refs_buf, instance.ns, lines)
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
		pending_items = 0,
		depth = DEFAULT_DEPTH,
		current_item = nil,
		refs_buf = nil,
		refs_win = nil,
		ns = vim.api.nvim_create_namespace("function_references_" .. instance_id),
		line_data = {},
		expanded_nodes = {},
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

-- === UI 渲染层 ===
function M._build_reference_lines(node, lines, indent, expanded_nodes)
	indent = indent or 0
	lines = lines or {}
	expanded_nodes = expanded_nodes or {}

	local icon = "󰅲"
	if node.name:match("[Dd]ebug") then
		icon = "⭐"
	end

	local has_refs = node.references and next(node.references) ~= nil
	local prefix = string.rep("  ", indent)
	local expanded = expanded_nodes[node.name .. node.uri]

	if has_refs then
		prefix = prefix .. (expanded and "ᐁ " or "ᐅ ")
	else
		prefix = prefix .. "  "
	end

	local location = ""
	if node.uri then
		location = " [" .. format_location(node.uri, node.selectionRange.start.line) .. "]"
	end

	table.insert(lines, {
		text = prefix .. icon .. " " .. node.name .. location,
		node = node,
		indent = indent,
		has_refs = has_refs,
	})

	if expanded and has_refs then
		for _, child in pairs(node.references) do
			M._build_reference_lines(child, lines, indent + 1, expanded_nodes)
		end
	end

	return lines
end

function M._display_ui(instance)
	if not instance.reference_tree or vim.tbl_isempty(instance.reference_tree.references) then
		vim.notify("No function references found", vim.log.levels.INFO)
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
	local win_width = math.floor(vim.api.nvim_get_option("columns") * 0.4)

	if not instance.refs_win or not vim.api.nvim_win_is_valid(instance.refs_win) then
		vim.cmd("vsplit")
		instance.refs_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(instance.refs_win, instance.refs_buf)
		vim.api.nvim_win_set_width(instance.refs_win, win_width)
		setup_window(instance.refs_win)
	end

	-- 构建并渲染内容
	instance.expanded_nodes[instance.reference_tree.name .. instance.reference_tree.uri] = true
	local lines = M._build_reference_lines(instance.reference_tree, {}, 0, instance.expanded_nodes)

	render_buffer_content(instance, lines)

	setup_buffer_keymaps(instance.refs_buf, instance.id)

	-- 设置状态行
	pcall(function()
		vim.cmd(
			"setlocal statusline=REFERENCES:\\ " .. instance.reference_tree.name:gsub("\\", "\\\\"):gsub(" ", "\\ ")
		)
	end)
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

	local node_id = item.node.name .. item.node.uri
	expanded_nodes[node_id] = not expanded_nodes[node_id]

	pcall(vim.api.nvim_buf_set_var, bufnr, "expanded_nodes", expanded_nodes)
	instance.expanded_nodes = expanded_nodes

	-- 重绘
	local lines = M._build_reference_lines(instance.reference_tree, {}, 0, expanded_nodes)
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
