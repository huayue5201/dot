-- lua/local/ai/ui.lua
---@brief 浮窗输入框：写问题，普通模式 <CR> 交给 on_submit(text)。不认识任何 agent。
--
-- 键位刻意不侵入 vim 的两种模式：
--   insert 里除了 <A-]>（minuet 拉补全）全走原生行为 —— <CR>/<C-j> 就是换行
--   normal 里 <CR> 发送、<Esc>/q 取消、<C-c> 取消
--
-- 为什么是浮窗而不是 :edit 临时文件 / codecompanion：提问是一次性的 5 秒动作，
-- 不值得开 buffer、切窗口、管文件生命周期。

local M = {}

--- 打开输入浮窗
---@param opts { title: string, on_submit: fun(text: string), prompt?: string }
---@return integer buf, integer win
function M.input(opts)
	local ui_w, ui_h = vim.o.columns, vim.o.lines
	local width = math.max(40, math.min(ui_w - 8, 92))
	local height = 8

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].buflisted = false
	-- markdown：让 minuet（auto_trigger_ft 含 markdown）在输入窗口里也能补全。
	-- 但只保留「手动」触发：空 nofile 上下文 + 中文提问，自动触发的建议必然跑题，
	-- 白花一次 FIM 请求（实测空 buffer 2.9s 后吐一整篇无关 ghost），
	-- 所以这里关掉 buffer 级 auto_trigger，用 <A-]> 按需拉一次。
	vim.bo[buf].filetype = "markdown"
	vim.b[buf].minuet_virtual_text_auto_trigger = false -- minuet virtualtext.lua:26 直接读这个变量

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = math.max(0, math.floor((ui_h - height) / 2) - 1),
		col = math.max(0, math.floor((ui_w - width) / 2)),
		title = " " .. opts.title .. " ",
		title_pos = "center",
		footer = " <Esc> 退编辑 · 普通模式 <CR> 发送 · q 关闭 · <A-]> 补全 ",
		footer_pos = "center",
		noautocmd = true,
	})
	vim.wo[win].wrap = true
	vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"

	local function close()
		-- 浮窗是 current window：直接关会把 insert 模式留给底下的 buffer，
		-- 下一个按键就按进代码里。先退出 insert。
		if vim.fn.mode():match("^[iR]") then
			vim.cmd("stopinsert")
		end
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	local function submit()
		local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		if vim.trim(text) == "" then
			close()
			return
		end
		close()
		opts.on_submit(text)
	end

	-- 只在 normal 模式发送：insert 里的 <CR> 保持原生换行，<C-j> 保持原生换行
	vim.keymap.set("n", "<CR>", submit, { buffer = buf, nowait = true, desc = "AI: 发送问题" })
	-- insert 模式下 <Esc>/<C-c> 保持默认（退出编辑模式，窗口留着）；normal 模式下才关窗
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, desc = "AI: 取消" })
	vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, desc = "AI: 取消" })
	vim.keymap.set("n", "<C-c>", close, { buffer = buf, nowait = true, desc = "AI: 取消" })

	vim.cmd("startinsert")
	return buf, win
end

return M
