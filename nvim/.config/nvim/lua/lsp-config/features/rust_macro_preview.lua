-- lua/lsp-config/features/rust_macro_preview.lua
-- Rust 宏展开预览（依赖 rust-analyzer 的 rust-analyzer/expandMacro 扩展请求）
--
-- 用法（在 LspAttach 中）：
--   require("lsp-config.features.rust_macro_preview").setup(client, bufnr)
--
-- 之后在当前 buffer：
--   - 用户命令 `:RustExpandMacro`
--   - 普通模式 `grm`
-- 在预览浮窗内：
--   - `]m` 展开下一层宏
--   - `[m` 返回上一层
--   - `q` / `<Esc>` 关闭

local M = {}

---@class RustMacroState
---@field client vim.lsp.Client
---@field bufnr integer
---@field buf integer|nil
---@field win integer|nil
---@field stack string[]  -- 每层展开结果，用于返回上一层
---@field level integer

-- 以 bufnr 为弱键，避免 buffer 卸载后泄漏
local state_by_buf = setmetatable({}, { __mode = "k" })

local function get_state(bufnr)
	return state_by_buf[bufnr]
end

--- 提取内容中的第一个宏调用名（形如 `foo!(...)` 或 `foo! { ... }`）
local function find_macro_name(content)
	if type(content) ~= "string" then
		return nil
	end
	return content:match("([%w_]+)!%s*[%({]")
end

--- 在源 buffer 中定位宏调用（返回 0-based 的 { line, character }）
local function find_macro_in_buffer(bufnr, macro_name)
	if not macro_name or not vim.api.nvim_buf_is_loaded(bufnr) then
		return nil
	end
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for i, line in ipairs(lines) do
		local s = line:find(macro_name .. "!%s*[%({]")
		if s then
			return { line = i - 1, character = s - 1 }
		end
	end
	return nil
end

--- 计算浮窗尺寸
local function calc_size(lines)
	local max_width = 0
	for _, l in ipairs(lines) do
		max_width = math.max(max_width, vim.fn.strdisplaywidth(l))
	end
	local width = math.min(math.max(max_width + 4, 30), math.floor(vim.o.columns * 0.6))
	local height = math.min(#lines + 3, math.floor(vim.o.lines * 0.7))
	return width, height
end

--- 关闭预览
function M.close(bufnr)
	local state = get_state(bufnr)
	if not state then
		return
	end

	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	state.win = nil
	state.buf = nil
	state.stack = {}
	state.level = 0
end

--- 渲染预览浮窗
function M.render(bufnr, content)
	local state = get_state(bufnr)
	if not state then
		return
	end

	content = content or "// No expansion"
	local lines = vim.split(content, "\n", { plain = true })

	-- 清理旧窗口/缓冲区
	-- 先置空 state.win，避免关闭旧窗口时其 WinClosed 回调误清空 stack/level
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		local old_win = state.win
		state.win = nil
		vim.api.nvim_win_close(old_win, true)
	end
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end

	local width, height = calc_size(lines)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].filetype = "rust"
	vim.bo[buf].bufhidden = "wipe"

	local title = string.format(" Macro Expansion (level %d) ", state.level)
	local border_line = string.rep("─", math.max(0, width - vim.fn.strdisplaywidth(title) - 2))
	local display_lines = { " " .. title .. border_line, "" }
	vim.list_extend(display_lines, lines)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, display_lines)

	-- 内容写入后再设为只读，否则 set_lines 会因 buffer 不可修改而报错
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true

	-- 右上角定位
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = 1,
		col = math.max(0, vim.o.columns - width - 2),
	})

	vim.wo[win].wrap = false
	vim.wo[win].cursorline = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false

	state.buf = buf
	state.win = win

	-- 自动清理：预览窗口被手动关闭时同步状态
	vim.api.nvim_create_autocmd("WinClosed", {
		buffer = buf,
		once = true,
		callback = function(ev)
			if state.win and tonumber(ev.match) == state.win then
				state.win = nil
				state.buf = nil
				state.stack = {}
				state.level = 0
			end
		end,
	})

	local close_preview = function()
		M.close(bufnr)
	end

	local function expand_nested()
		local macro_name = find_macro_name(content)
		if not macro_name then
			vim.notify("没有更多可展开的宏", vim.log.levels.INFO)
			return
		end

		-- 在源文件中定位该宏调用（rust-analyzer 的 expandMacro 需要源文件 position）
		local pos = find_macro_in_buffer(bufnr, macro_name)
		if not pos then
			vim.notify(
				"无法在源文件中定位宏 `" .. macro_name .. "!`，请将光标移到目标宏后按 grm",
				vim.log.levels.WARN
			)
			return
		end

		state.stack[#state.stack + 1] = content
		state.level = state.level + 1
		M.expand(state.client, bufnr, pos)
	end

	local function expand_prev()
		if state.level == 0 then
			vim.notify("已经是最外层", vim.log.levels.INFO)
			return
		end
		local prev = table.remove(state.stack)
		state.level = state.level - 1
		M.render(bufnr, prev)
	end

	vim.keymap.set("n", "q", close_preview, { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "<Esc>", close_preview, { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "]m", expand_nested, { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", "[m", expand_prev, { buffer = buf, noremap = true, silent = true })
end

--- 请求 rust-analyzer 展开宏
---@param client vim.lsp.Client
---@param bufnr integer 源 buffer（不是预览浮窗）
---@param position table|nil 0-based 的 { line, character }，nil 则用光标位置
function M.expand(client, bufnr, position)
	if not client or vim.api.nvim_buf_is_valid(bufnr) ~= true then
		return
	end

	-- 注意：make_position_params 的第一参数是窗口 ID 而非 bufnr，
	-- 因此分两种情况构造，避免把 bufnr 误当窗口 ID。
	local params
	if position then
		-- 嵌套展开：textDocument 指向源 buffer，position 为定位到的宏位置
		params = {
			textDocument = vim.lsp.util.make_text_document_params(bufnr),
			position = position,
		}
	else
		-- 顶层展开：使用当前窗口光标（grm 触发时当前窗口即源 buffer）
		params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-16")
	end

	client:request("rust-analyzer/expandMacro", params, function(err, result)
		if err or not result then
			vim.notify("宏展开失败: " .. tostring(err or "无结果"), vim.log.levels.ERROR)
			return
		end
		M.render(bufnr, result.expansion or "// No expansion")
	end)
end

--- 切换预览（在源 buffer 中调用）
function M.toggle(client, bufnr)
	local state = get_state(bufnr)
	if not state then
		return
	end

	if state.win and vim.api.nvim_win_is_valid(state.win) then
		M.close(bufnr)
		return
	end

	state.client = client
	state.stack = {}
	state.level = 0
	M.expand(client, bufnr, nil)
end

--- 安装到某个 LSP client / buffer
function M.setup(client, bufnr)
	if not client or client.name ~= "rust-analyzer" then
		return
	end
	if not client:supports_method("rust-analyzer/expandMacro", bufnr) then
		return
	end

	state_by_buf[bufnr] = {
		client = client,
		bufnr = bufnr,
		buf = nil,
		win = nil,
		stack = {},
		level = 0,
	}

	local opts = { buffer = bufnr, noremap = true, silent = true, desc = "Toggle Rust Macro Preview" }
	vim.keymap.set("n", "grm", function()
		M.toggle(client, bufnr)
	end, opts)

	vim.api.nvim_buf_create_user_command(bufnr, "RustExpandMacro", function()
		M.toggle(client, bufnr)
	end, { desc = "切换 Rust 宏展开预览窗口" })
end

-- 导出内部函数供测试
M._find_macro_name = find_macro_name
M._find_macro_in_buffer = find_macro_in_buffer

return M
