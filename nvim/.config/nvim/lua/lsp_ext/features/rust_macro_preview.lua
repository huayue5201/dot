-- lua/lsp_ext/features/rust_macro_preview.lua
-- Rust 宏展开预览（依赖 rust-analyzer 的 rust-analyzer/expandMacro 扩展请求）
--
-- 展示方式：底部横向分屏（belowright split）里的只读真实 buffer，不是浮窗。
--   好处：treesitter 高亮、折叠、/ 搜索、yank、:g 全部可用；不抢焦点，光标仍在源码里。
--   标题走 winbar（宏名 + 层级 + 源位置），不往 buffer 内容里塞伪 header 行。
--
-- 用法（在 LspAttach 中）：
--   require("lsp_ext.features.rust_macro_preview").setup(client, bufnr)
--
-- 之后在当前 buffer：
--   - 用户命令 `:RustExpandMacro`
--   - 普通模式 `grm`（再按一次关闭）
-- 在预览分屏内（需先 <C-w>j 进去）：
--   - `<CR>` 跳到源码里对应的宏调用
--   - `]m` 展开上一层里出现的内层宏
--   - `[m` 返回上一层
--   - `q` / `<Esc>` 关闭预览

local M = {}

local lsp_request = require("lib.lsp_request")

---@class RustMacroState
---@field client vim.lsp.Client
---@field bufnr integer 源 buffer
---@field buf integer|nil 预览 buffer
---@field win integer|nil 预览窗口
---@field source_win integer|nil 打开预览前的窗口（关窗/刷新后焦点回这里）
---@field stack { content: string, level: integer, macro: string|nil }[] 每层快照，用于返回
---@field level integer
---@field macro string|nil 当前层宏名
---@field origin { line: integer, character: integer }|nil 当前层宏调用在源 buffer 的位置

-- 以 bufnr 为弱键，避免 buffer 卸载后泄漏
local state_by_buf = setmetatable({}, { __mode = "k" })

local function get_state(bufnr)
	return state_by_buf[bufnr]
end

local function win_valid(win)
	return type(win) == "number" and vim.api.nvim_win_is_valid(win)
end

local function buf_valid(buf)
	return type(buf) == "number" and vim.api.nvim_buf_is_valid(buf)
end

--- 提取内容中的第一个宏调用名（形如 `foo!(...)` 或 `foo! { ... }`）
local function find_macro_name(content)
	if type(content) ~= "string" then
		return nil
	end
	return content:match("([%w_]+)!%s*[%({]")
end

--- byte 列（0-based）转 LSP position
local function to_lsp_position(bufnr, line_idx, byte_col, encoding)
	local line = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1] or ""
	local prefix = line:sub(1, byte_col)
	encoding = encoding or "utf-16"
	if encoding == "utf-8" then
		return { line = line_idx, character = byte_col }
	end
	if encoding == "utf-32" then
		return { line = line_idx, character = vim.fn.strchars(prefix) }
	end
	-- 注意：指定 encoding 时 vim.str_utfindex 只返回一个值（该编码下的索引）
	return { line = line_idx, character = vim.str_utfindex(prefix, "utf-16") }
end

--- 光标位置（0-based LSP position）；当前窗口不是源 buffer 时找一个显示它的窗口
local function cursor_position(bufnr, encoding)
	local win = vim.api.nvim_get_current_win()
	if vim.api.nvim_win_get_buf(win) ~= bufnr then
		win = nil
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(w) == bufnr then
				win = w
				break
			end
		end
	end
	if not win then
		return { line = 0, character = 0 }
	end
	local cur = vim.api.nvim_win_get_cursor(win)
	return to_lsp_position(bufnr, cur[1] - 1, cur[2], encoding)
end

--- 在源 buffer 中定位宏调用（0-based 的 { line, character }）
--- rust-analyzer 的 expandMacro 只接受 (textDocument, position)，没有「在展开结果里递归」的能力，
--- 所以内层宏只能在源文件里反查：取离 origin 最近的那一处同名调用。
local function find_macro_in_buffer(bufnr, macro_name, origin, encoding)
	if not macro_name or not vim.api.nvim_buf_is_loaded(bufnr) then
		return nil
	end
	local pat = macro_name .. "!%s*[%({]"
	local origin_line = origin and origin.line or nil
	local best, best_score
	for i, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		local idx = 1
		while true do
			local s = line:find(pat, idx)
			if not s then
				break
			end
			local score = origin_line and math.abs((i - 1) - origin_line) or (i - 1)
			if not best_score or score < best_score then
				best = to_lsp_position(bufnr, i - 1, s - 1, encoding)
				best_score = score
			end
			idx = s + 1
		end
	end
	return best
end

--- 关闭预览（焦点回到源码窗口）
function M.close(bufnr)
	local state = get_state(bufnr)
	if not state then
		return
	end
	local win = state.win
	state.win = nil
	state.buf = nil
	state.stack = {}
	state.level = 0
	state.macro = nil
	state.origin = nil
	if win_valid(win) then
		local src = state.source_win
		vim.api.nvim_win_close(win, true)
		if win_valid(src) then
			vim.api.nvim_set_current_win(src)
		end
	end
end

--- 预览 buffer 的按键
local function bind_preview_keys(state, buf)
	local function close()
		M.close(state.bufnr)
	end

	vim.keymap.set("n", "q", close, { buffer = buf, desc = "关闭宏展开预览" })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, desc = "关闭宏展开预览" })

	-- 跳回源码中该宏的调用位置
	vim.keymap.set("n", "<CR>", function()
		local src, origin = state.source_win, state.origin
		if not win_valid(src) or not origin then
			vim.notify("找不到宏调用位置", vim.log.levels.WARN)
			return
		end
		vim.api.nvim_set_current_win(src)
		vim.api.nvim_win_set_cursor(src, { origin.line + 1, origin.character })
	end, { buffer = buf, desc = "跳到源码中的宏调用" })

	local function expand_prev()
		local prev = table.remove(state.stack)
		if not prev then
			vim.notify("已经是最外层", vim.log.levels.INFO)
			return
		end
		state.level = prev.level
		state.macro = prev.macro
		state.origin = prev.origin
		M.render(state.bufnr, prev.content, prev.macro)
	end

	local function expand_nested()
		-- 取展开内容里的第一个宏名（当前层的内容记在预览 buffer 里）
		local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		local name = find_macro_name(content)
		if not name then
			vim.notify("展开结果里没有可继续展开的宏", vim.log.levels.INFO)
			return
		end
		local pos = find_macro_in_buffer(state.bufnr, name, state.origin, state.client.offset_encoding)
		if not pos then
			vim.notify(
				"源文件里找不到 `"
					.. name
					.. "!` 的调用位置 —— rust-analyzer 不支持从展开结果递归展开，"
					.. "请把光标移到该宏上按 grm",
				vim.log.levels.WARN
			)
			return
		end
		state.stack[#state.stack + 1] = {
			content = content,
			level = state.level,
			macro = state.macro,
			origin = state.origin,
		}
		state.level = state.level + 1
		M.expand(state.client, state.bufnr, pos, name)
	end

	vim.keymap.set("n", "]m", expand_nested, { buffer = buf, desc = "展开内层宏" })
	vim.keymap.set("n", "[m", expand_prev, { buffer = buf, desc = "返回上一层展开" })
end

--- 渲染预览（复用已有 buffer/窗口，只换内容，避免丢滚动位置）
---@param bufnr integer 源 buffer
---@param content string 展开结果
---@param macro string|nil 宏名（nil 时从内容里猜）
function M.render(bufnr, content, macro)
	local state = get_state(bufnr)
	if not state then
		return
	end

	content = content or "// No expansion"
	local lines = vim.split(content, "\n", { plain = true })

	local prev_win = vim.api.nvim_get_current_win()

	-- 1) 复用或新建 scratch buffer
	local buf = state.buf
	if not buf_valid(buf) then
		buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].swapfile = false
		vim.bo[buf].undolevels = -1
		vim.b[buf].rust_macro_preview = true
		state.buf = buf
		bind_preview_keys(state, buf)
	end
	vim.bo[buf].modifiable = true
	vim.bo[buf].readonly = false
	vim.bo[buf].filetype = "rust"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true

	state.macro = macro or state.macro or find_macro_name(content)

	-- 2) 复用或新建窗口（belowright split，下分屏）
	local max_h = math.max(6, math.floor((vim.o.lines - vim.o.cmdheight) * 0.4))
	local win = state.win
	if not win_valid(win) then
		local anchor = win_valid(state.source_win) and state.source_win or prev_win
		vim.api.nvim_set_current_win(anchor)
		vim.cmd("belowright split")
		win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(win, buf)

		vim.api.nvim_win_set_height(win, math.min(math.max(#lines, 6), max_h))

		vim.wo[win].number = false
		vim.wo[win].relativenumber = false
		vim.wo[win].cursorline = false
		vim.wo[win].signcolumn = "no"
		vim.wo[win].foldcolumn = "0"
		vim.wo[win].wrap = true
		vim.wo[win].list = false
		vim.wo[win].scrolloff = 2

		state.win = win
		if not win_valid(state.source_win) then
			state.source_win = prev_win
		end

		vim.api.nvim_create_autocmd("WinClosed", {
			pattern = tostring(win),
			once = true,
			callback = function()
				if state.win == win then
					state.win = nil
					state.buf = nil
					state.stack = {}
					state.level = 0
					state.macro = nil
					state.origin = nil
				end
			end,
		})
	else
		-- 复用窗口：内容变长时跟着长高（不超过上限），不会缩短
		local need = math.min(math.max(#lines, 1), max_h)
		if need > vim.api.nvim_win_get_height(win) then
			vim.api.nvim_win_set_height(win, need)
		end
	end

	-- 3) winbar 标题：宏名 + 层级 + 源位置
	local name = (state.macro or "macro"):gsub("!$", "")
	local where = "L" .. (state.level + 1)
	if state.origin then
		local fname = vim.api.nvim_buf_get_name(bufnr)
		where = string.format("%s · %s:%d", where, vim.fn.fnamemodify(fname, ":t"), state.origin.line + 1)
	end
	local escaped = (" " .. name .. "!  " .. where):gsub("%%", "%%%%")
	vim.wo[win].winbar = "%#Title#  宏展开 %*%#Comment#" .. escaped .. " %*"

	-- 4) 焦点回原窗口（预览不抢焦点）
	if win_valid(prev_win) and prev_win ~= win then
		vim.api.nvim_set_current_win(prev_win)
	end
end

--- 请求 rust-analyzer 展开宏
---@param client vim.lsp.Client
---@param bufnr integer 源 buffer（不是预览窗口）
---@param position table|nil 0-based 的 { line, character }，nil 则用光标位置
---@param macro string|nil 已知的宏名（仅用于标题）
function M.expand(client, bufnr, position, macro)
	if not client or vim.api.nvim_buf_is_valid(bufnr) ~= true then
		return
	end

	local state = get_state(bufnr)

	-- 解析一次位置：顶层用光标，嵌套用传入位置；两者都记到 origin（winbar 展示 + 内层宏定位基准）
	local pos = position or cursor_position(bufnr, client.offset_encoding)
	if state then
		state.origin = pos
	end

	local params = {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
		position = pos,
	}

	-- 超时/失败由 lsp-request 统一提示（notify = true）
	lsp_request.request(client, "rust-analyzer/expandMacro", params, {
		bufnr = bufnr,
		what = "expandMacro",
		notify = true,
	}, function(result, err)
		if err or not result then
			return
		end
		M.render(bufnr, result.expansion or "// No expansion", macro or result.name)
	end)
end

--- 切换预览（在源 buffer 中调用）
function M.toggle(client, bufnr)
	local state = get_state(bufnr)
	if not state then
		return
	end

	if win_valid(state.win) then
		M.close(bufnr)
		return
	end

	state.client = client
	state.stack = {}
	state.level = 0
	state.macro = nil
	state.origin = nil
	state.source_win = vim.api.nvim_get_current_win()
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
		source_win = nil,
		stack = {},
		level = 0,
		macro = nil,
		origin = nil,
	}

	local opts = { buffer = bufnr, noremap = true, silent = true, desc = "Toggle Rust Macro Preview" }
	vim.keymap.set("n", "grm", function()
		M.toggle(client, bufnr)
	end, opts)

	vim.api.nvim_buf_create_user_command(bufnr, "RustExpandMacro", function()
		M.toggle(client, bufnr)
	end, { desc = "切换 Rust 宏展开预览窗口" })

	-- 源 buffer 卸载时清理
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = bufnr,
		once = true,
		callback = function()
			M.close(bufnr)
			state_by_buf[bufnr] = nil
		end,
	})
end

-- 导出内部函数供测试
M._state = get_state
M._find_macro_name = find_macro_name
M._find_macro_in_buffer = find_macro_in_buffer

return M
