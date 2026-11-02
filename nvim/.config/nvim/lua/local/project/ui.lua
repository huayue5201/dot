-- 项目概览：窗口 / 按键（采集与渲染结果的落点）
local util = require("local.project.util")
local store = require("local.project.store")
local render_mod = require("local.project.render")
local collect_mod = require("local.project.collect")

local join = util.join
local resolve_root = util.resolve_root
local git_sync = util.git_sync
local notify = util.notify
local render = render_mod.render
local ensure_hl = render_mod.ensure_hl
local ns = render_mod.ns
local collect = collect_mod.collect
local cache = store.cache
local state = store.state

local M = {}

--- 懒加载 public API：ask / chat 在 init 里，直接 require 会成环（init → ui → init）
local function public()
	return require("local.project")
end

----------------------------------------------------------------------
-- 窗口 / 按键
----------------------------------------------------------------------

local function jump(buf)
	local st = state[buf]
	if not st then
		return
	end
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local path = st.paths[line]
	if not path then
		notify("光标这一行没有文件路径（试试「结构」「活跃区」「最大文件」里的条目）", vim.log.levels.WARN)
		return
	end
	local target = join(st.root, path)
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_close(win, true)
	if st.origin_win and vim.api.nvim_win_is_valid(st.origin_win) then
		vim.api.nvim_set_current_win(st.origin_win)
	end
	vim.cmd.edit(vim.fn.fnameescape(target))
end

local function attach(buf, origin_win, origin_buf)
	state[buf] = { paths = {}, origin_win = origin_win }
	-- buffer 被 wipe 时清掉状态，别让 state 表越攒越大
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			state[buf] = nil
		end,
	})
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].undolevels = -1
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "markdown"

	local opts = { buffer = buf, silent = true, nowait = true }
	local function close()
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_close(win, true)
		-- 关掉概览回到原来的 buffer 时，别留下一个空的 nofile buffer
		if origin_buf and vim.api.nvim_buf_is_valid(origin_buf) then
			vim.api.nvim_set_current_buf(origin_buf)
		end
		if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
	vim.keymap.set("n", "q", close, vim.tbl_extend("force", opts, { desc = "关闭项目概览" }))
	vim.keymap.set("n", "<Esc>", close, vim.tbl_extend("force", opts, { desc = "关闭项目概览" }))
	vim.keymap.set("n", "gd", function()
		jump(buf)
	end, vim.tbl_extend("force", opts, { desc = "跳到光标下的文件" }))
	vim.keymap.set("n", "r", function()
		M.open({ full = state[buf].full, force = true })
	end, vim.tbl_extend("force", opts, { desc = "重新采集" }))
	-- 用 t 而不是 <Tab>：<Tab> 在 normal 模式等同于 <C-i>，会抢掉 jumplist 前进
	vim.keymap.set("n", "t", function()
		M.open({ full = not state[buf].full })
	end, vim.tbl_extend("force", opts, { desc = "精简 ⇄ 完整" }))
	-- A(Ask)：把这份概览的紧凑摘要连同一个问题发给 AI 后端（走 local.ai）
	vim.keymap.set("n", "A", function()
		local st = state[buf]
		if st and st.data then
			public().ask()
		end
	end, vim.tbl_extend("force", opts, { desc = "带着概览问 AI" }))
	-- C(Chat)：把摘要塞进 codecompanion chat，在 chat 里接着聊
	vim.keymap.set("n", "C", function()
		local st = state[buf]
		if st and st.data then
			public().chat({})
		end
	end, vim.tbl_extend("force", opts, { desc = "概览进 codecompanion chat" }))
end

local function fill(buf, data, full)
	local lines, hls, paths = render(data, full)
	state[buf].paths = paths
	state[buf].root = data.root
	state[buf].data = data
	state[buf].full = full
	-- 记一份「最近一次采集」，这样：ProjectAsk 在任何 buffer 里都能直接用，不用再跑一遍 tokei
	store.last = { root = data.root, data = data }
	ensure_hl()
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for lnum, spans in pairs(hls) do
		for _, span in ipairs(spans) do
			pcall(vim.api.nvim_buf_set_extmark, buf, ns, lnum - 1, span[2], {
				end_col = span[3],
				hl_group = span[1],
				priority = 200,
			})
		end
	end
	vim.bo[buf].modifiable = false
	vim.bo[buf].modified = false
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.api.nvim_win_set_cursor(win, { 1, 0 })
	end
end

--- 采集并渲染到已有 buffer（先占位再异步填）
local function start_collect(buf, root, full)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		("# %s"):format(vim.fs.basename(root)),
		"",
		"采集中（tokei / git log 并行跑，大仓库要几秒）…",
	})
	vim.bo[buf].modifiable = false
	collect(root, full, function(data)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		cache[data.root] = { head = data.head, data = data }
		fill(buf, data, full)
	end)
end

--- 打开/切换概览窗口
---@param opts? { full?: boolean, root?: string, force?: boolean }
function M.open(opts)
	opts = opts or {}
	-- 不在 git 仓库里也能用：就地按目录统计（collect 里会走 walk_files 兜底）
	local root = resolve_root(opts.root)
	local full = opts.full == true

	local function focus(buf)
		local wins = vim.fn.win_findbuf(buf)
		if #wins > 0 then
			vim.api.nvim_set_current_win(wins[1])
		end
	end

	-- 已经采集过这个仓库：复用那个 buffer（窗口被关掉的话重新 split 出来，缓存还在）
	for buf, st in pairs(state) do
		if vim.api.nvim_buf_is_valid(buf) and st.root == root then
			if #vim.fn.win_findbuf(buf) == 0 then
				vim.cmd("silent! botright split")
				vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
				vim.api.nvim_win_set_height(0, math.max(12, math.floor(vim.o.lines * 0.6)))
			end
			if opts.force then
				start_collect(buf, root, full)
			elseif st.data and st.full ~= full then
				fill(buf, st.data, full)
			end
			focus(buf)
			return
		end
	end

	local origin_win = vim.api.nvim_get_current_win()
	local origin_buf = vim.api.nvim_get_current_buf()
	local buf = vim.api.nvim_create_buf(false, true)
	-- 带 scheme 的名字：不会被当成 cwd 下的相对文件路径（也不和真实文件抢 buffer 名）。
	-- 先用仓库名（statusline 里短），重名再退回完整路径。
	local name = "project://" .. vim.fs.basename(root)
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == name then
			name = "project://" .. root
			break
		end
	end
	vim.api.nvim_buf_set_name(buf, name)
	-- 关掉 markview 的原地渲染：这里是数据表，二次排版只会加噪音（顺序：先禁后设 ft）
	pcall(function()
		require("markview.state").set_buffer_state(buf, { enable = false })
	end)

	attach(buf, origin_win, origin_buf)

	local win = vim.api.nvim_get_current_win()
	vim.cmd("silent! botright split")
	local newwin = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(newwin, buf)
	vim.api.nvim_win_set_height(newwin, math.max(12, math.floor(vim.o.lines * 0.6)))
	vim.api.nvim_set_current_win(newwin)
	state[buf].origin_win = win

	local cached = cache[root]
	if cached and cached.head == git_sync(root, { "rev-parse", "--short", "HEAD" }) then
		fill(buf, cached.data, full)
		return
	end

	start_collect(buf, root, full)
end

function M.setup()
	vim.api.nvim_create_user_command("Project", function(args)
		M.open({ full = args.bang })
	end, { bang = true, desc = "项目概览（!: 完整版）" })
	vim.api.nvim_create_user_command("ProjectAsk", function()
		public().ask()
	end, { desc = "带着项目概览问 AI（精简摘要随问题发出）" })
	vim.api.nvim_create_user_command("ProjectChat", function(args)
		public().chat({ adapter = args.args ~= "" and args.args or nil })
	end, {
		nargs = "?",
		desc = "把项目概览摘要放进 codecompanion chat（默认 deepseek，可传 pi）",
		complete = function()
			return { "deepseek", "pi", "default" }
		end,
	})
	vim.keymap.set("n", "<leader>ii", function()
		M.open()
	end, { desc = "项目概览（规模 / 结构 / 活跃区）" })
	vim.keymap.set("n", "<leader>ia", function()
		public().ask()
	end, { desc = "带着项目概览问 AI" })
	vim.keymap.set("n", "<leader>ic", function()
		public().chat()
	end, { desc = "项目概览放进 codecompanion chat" })
end

return M
