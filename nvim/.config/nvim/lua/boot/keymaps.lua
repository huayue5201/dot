local mc_ns = vim.api.nvim_create_namespace("nvim.multicursor")
vim.keymap.set("n", "<Esc>", function()
	-- 1. 清除 multicursor 的视觉标记
	vim.api.nvim_buf_clear_namespace(0, mc_ns, 0, -1)
	-- 2. 清除搜索高亮
	vim.cmd("nohlsearch")
end)

-- 📝 Basic operations
vim.keymap.set("n", "c", '"_c', { desc = "Basic: change to blackhole" })

vim.keymap.set("n", "dd", function()
	return vim.fn.getline(".") == "" and '"_dd' or "dd"
end, { expr = true, desc = "Basic: delete line (empty → blackhole)" })

vim.keymap.set("n", "j", "gj")
vim.keymap.set("n", "k", "gk")

vim.keymap.set("x", "i", function()
	if #vim.fn.getline(".") == 0 then
		return [["_cc]]
	else
		return "i"
	end
end, { expr = true })

-- p / P / gp / gP / ]p / [p 由 smart-paste.nvim 接管（更聪明的缩进对齐，见 lua/plugins/editor/smart-paste.lua）。
-- 这里不要再映射 p：boot.keymaps 在 boot.pack 之后执行，会覆盖插件的映射。
-- vim.keymap.set("n", "p", "p`[v`]=")

vim.keymap.set("x", "y", function()
	local save = vim.fn.getpos(".")
	vim.cmd("normal! y")
	vim.fn.setpos(".", save)
end, { desc = "Yank: 保持光标位置" })

-- 保存键统一收纳在 <localleader>s 分组下（s 本身不映射，避免成为子映射前缀而拖慢触发）
vim.keymap.set("n", "<localleader>sw", "<cmd>w<cr>", { silent = true, desc = "Save: write buffer" })

vim.keymap.set("n", "<localleader>sa", function()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_get_option_value("modified", { buf = buf }) then
			vim.api.nvim_buf_call(buf, function()
				vim.cmd.write()
			end)
		end
	end
end, { silent = true, desc = "Save: write all modified buffers" })

vim.keymap.set("n", "<localleader>sl", function()
	require("feat.save_panel").toggle()
end, { silent = true, desc = "Save: list unsaved buffers (panel)" })

require("feat.save_panel").setup() -- :SavePanel 命令

-- quickfix / loclist 的栈管理（:QfStack / :QfStackLoc，<localleader>Q），
-- 和 quicker.nvim（<localleader>q / l）互补：那边看全貌，这边按标题挑一层
require("ui.qf").setup()

-- 关闭当前 buffer：有分屏时先收掉当前窗口（不动其它分屏），
-- buffer 不再被任何窗口显示后再交给 tab_workspace 删除（含共享归属 / 未保存确认）。
-- 不能用 `:bd` / `:bp | bd #`：它们会把窗口换成别的文件（分屏看起来“没关掉”），
-- 也不会维护 tab 工作区的 buffer 归属。
-- noice.nvim 等插件会常驻隐藏浮窗（[Cmd]/[Msg]/[Dialog]/[Pager]），
-- nvim_tabpage_list_wins 会把浮窗也算进去，导致“多窗口”误判、win_close 关不动。
-- 因此这里只统计当前 tab 里真正参与布局的（非浮动）窗口。
local tw_util = require("tab_workspace.util")

local function real_wins()
	local wins = {}
	for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if not tw_util.is_float_win(w) then
			wins[#wins + 1] = w
		end
	end
	return wins
end

-- 说明：这里叫 close_buffer 而不是 smart_close，避免和 feat.navigation.handlers.smart_close
-- （关窗口语义，面板 q 用）混淆：本函数是删 buffer 语义。
local function close_buffer()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	-- 特殊 buffer（终端 / 文件树 / 浮窗 / help 等）：只关窗口，不删 buffer
	if vim.bo[buf].buftype ~= "" then
		if #real_wins() > 1 then
			pcall(vim.api.nvim_win_close, 0, false)
			return
		end

		-- 最后一个窗口不能 :close（E444），改成换到别的 buffer（没有就开空 buffer），
		-- 再把当前这个特殊 buffer 删掉。
		local alt = vim.fn.bufnr("#")
		if alt ~= -1 and alt ~= buf and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
			vim.cmd("buffer " .. alt)
		else
			vim.cmd("enew")
		end
		local shown = false
		for _, w in ipairs(vim.fn.win_findbuf(buf)) do
			if vim.api.nvim_win_get_config(w).relative == "" then
				shown = true
				break
			end
		end
		if not shown and vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
		return
	end

	-- 当前 tab 有多个真实分屏：收掉当前分屏（其它窗口布局不动），
	-- 若这个 buffer 还在别的窗口 / 别的 tab 里用着，就到此为止。
	if #real_wins() > 1 then
		pcall(vim.api.nvim_win_close, 0, false)
		local still = false
		for _, w in ipairs(vim.fn.win_findbuf(buf)) do
			if vim.api.nvim_win_get_config(w).relative == "" then
				still = true
				break
			end
		end
		if still then
			return
		end
	end

	-- 无分屏（或刚收完最后一个显示它的窗口）：先把窗口切到上一个可用的 buffer，
	-- 再删 buffer；没有可选的就留一个空 buffer，窗口本身不被销毁。
	local alt = vim.fn.bufnr("#")
	if alt ~= -1 and alt ~= buf and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
		vim.cmd("buffer " .. alt)
	end
	require("tab_workspace").close_buffer(buf)
end

-- 只用 <leader>bq：<D-w> 是终端关闭 tab 的默认键，<c-esc> 终端只发裸 ESC（分不出来）。
vim.keymap.set("n", "<leader>bq", close_buffer, { silent = true, desc = "Basic: close buffer" })

-- vim.keymap.set("n", "<leader>cab", function()
-- 	local current = vim.api.nvim_get_current_buf()
--
-- 	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
-- 		if buf ~= current and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
-- 			local win = vim.fn.bufwinid(buf)
-- 			if win ~= -1 then
-- 				-- 直接关闭窗口，跳过 smart_close 的复杂逻辑
-- 				pcall(vim.api.nvim_win_close, win, { force = true })
-- 			else
-- 				-- 如果没有窗口显示该buffer，直接删除buffer
-- 				pcall(vim.api.nvim_buf_delete, buf, { force = false })
-- 			end
-- 		end
-- 	end
-- end, { silent = true, desc = "Close other buffers safely" })

-- vim.keymap.set("n", "<leader>fd", ":lcd %:p:h<CR>", { silent = true, desc = "更改为文件目录" })
-- local function undotree()
-- 	local close = require("undotree").open({
-- 		title = "undotree",
-- 		command = "topleft 48vnew",
-- 	})
-- 	if not close then
-- 		vim.bo.filetype = "undotree"
-- 	end
-- end
--
-- vim.keymap.set("n", "<leader>eu", undotree, { desc = "UndoTree: toggle undotree" })

vim.keymap.set("n", "<leader>rtw", function()
	local new_wrap = not vim.wo.wrap
	vim.wo.wrap = new_wrap
	print("Wrap " .. (new_wrap and "enabled" or "disabled"))
end, { desc = "Toggle line wrap" })

-- 🏷 Tab operaions
vim.keymap.set("n", "<leader>ltn", "<cmd>$tabnew<cr>", {
	silent = true,
	desc = "Tab: 新建（不设根目录，工作区版见 <leader>lwn）",
})
vim.keymap.set("n", "<leader>lth", ":-tabmove<CR>", {
	silent = true,
	desc = "Tab: 左移",
})
vim.keymap.set("n", "<leader>ltl", ":+tabmove<CR>", {
	silent = true,
	desc = "Tab: 右移",
})

vim.keymap.set("n", "<leader>ltq", "<cmd>tabclose<cr>", {
	silent = true,
	desc = "Tab: 关闭（不保存会话，工作区版见 <leader>lwq）",
})
vim.keymap.set("n", "<leader>lws", function()
	require("tab_workspace").prompt_root()
end, { silent = true, desc = "Tab: 设置工作区根目录" })
vim.keymap.set("n", "<leader>lwn", function()
	require("tab_workspace").new_workspace()
end, { silent = true, desc = "工作区: 新建（保存会话 + 新 tab + 设置根目录）" })
vim.keymap.set("n", "<leader>lwq", function()
	require("tab_workspace").close_workspace()
end, { silent = true, desc = "工作区: 关闭（保存会话 + 关闭 tab）" })
vim.keymap.set("n", "<leader>ltp", function()
	require("tab_workspace").alternate()
end, { silent = true, desc = "Tab: 切换到上一个（alternate）" })
vim.keymap.set("n", "<leader>lwe", function()
	require("tab_workspace").edit_local_settings()
end, { silent = true, desc = "工作区: 编辑本地配置 (.nvim.lua)" })
vim.keymap.set("n", "<leader>lwr", function()
	require("tab_workspace").rename_workspace()
end, { silent = true, desc = "工作区: 重命名（留空回车 = 恢复默认）" })
vim.keymap.set("n", "<leader>lwl", function()
	require("tab_workspace").picker({ select = require("ui.picker").select })
end, { silent = true, desc = "工作区: 列表/切换（打开中 + 已保存 + 新目录）" })
vim.keymap.set("n", "<leader>lw+", function()
	require("tab_workspace").attach_root()
end, { silent = true, desc = "工作区: 附加辅助根（多根，cwd 仍是主根）" })
vim.keymap.set("n", "<leader>lw-", function()
	require("tab_workspace").detach_root()
end, { silent = true, desc = "工作区: 移除辅助根" })
vim.keymap.set("n", "<leader>lwt", function()
	require("tab_workspace").workspace_tree()
end, { silent = true, desc = "工作区: 多根树（主根 + 辅助根）" })
vim.keymap.set("n", "<leader>lwb", function()
	require("tab_workspace").root_back()
end, { silent = true, desc = "工作区: 根目录回到上一个（并锁定）" })
vim.keymap.set("n", "<leader>lwR", function()
	require("tab_workspace").root_unpin()
end, { silent = true, desc = "工作区: 解除根目录锁定（恢复自动跟随）" })
vim.keymap.set("n", "<leader>lto", "<cmd>tabonly<cr>", { silent = true, desc = "Tab: 关闭其他 tab" })

-- 🌐 Upstream 状态（feat.fork_upstream，属于 <leader>h git 分组）
vim.keymap.set(
	"n",
	"<leader>hu",
	"<cmd>ForkUpstream<cr>",
	{ silent = true, desc = "Upstream: 检查上游更新（fetch + 详情）" }
)
vim.keymap.set(
	"n",
	"<leader>hU",
	"<cmd>ForkUpstreamFix<cr>",
	{ silent = true, desc = "Upstream: 自动补 upstream 远端" }
)

-- 📜 Messages & reload
vim.keymap.set("n", "<leader>rte", "<cmd>edit<cr>", { silent = true, desc = "Basic: reload buffer" })
-- <leader>rtR：重载当前配置文件（清模块缓存 + 重跑引用它的插件 config），见 lua/feat/config_reload.lua
-- 不用 rl：Lua buffer 里 rl 是「运行 Lua（osv）」，见 lua/dap_ext/adapters/nlua.lua
require("feat.config_reload").setup()
vim.keymap.set(
	"n",
	"<leader>rtR",
	"<cmd>ConfigReload<cr>",
	{ silent = true, desc = "Config: 重载当前文件的模块缓存 + 插件 config" }
)

-- 🔍 Search
vim.keymap.set("x", "/", "<C-\\><C-n>`</\\%V", { desc = "Search: forward in visual range" })
vim.keymap.set("x", "?", "<C-\\><C-n>`>?\\%V", { desc = "Search: backward in visual range" })
vim.keymap.set(
	"n",
	"z/",
	'/\\%><C-r>=line("w0")-1<CR>l\\%<<C-r>=line("w$")+1<CR>l',
	{ silent = false, desc = "Search: within viewport" }
)

-- 📋 Copy path
vim.keymap.set("n", "<leader>yp", function()
	vim.fn.setreg("+", vim.fn.expand("%:p"))
	print("Copied: " .. vim.fn.expand("%:p"))
end, { silent = true, desc = "Path: copy absolute" })

vim.keymap.set("n", "<leader>yf", function()
	vim.fn.setreg("+", vim.fn.expand("%:f"))
	print("Copied: " .. vim.fn.expand("%:f"))
end, { silent = true, desc = "Path: copy relative" })

vim.keymap.set("n", "<leader>yt", function()
	vim.fn.setreg("+", vim.fn.expand("%:t"))
	print("Copied: " .. vim.fn.expand("%:t"))
end, { silent = true, desc = "Path: copy filename" })

-- 🪟 Window management
-- vim.keymap.set("n", "<Leader>caw", function()
-- 	local nav = require("feat.navigation")
-- 	local cur_win = vim.api.nvim_get_current_win()
-- 	local cur_buf = vim.api.nvim_win_get_buf(cur_win)
-- 	local cur_dir = vim.fn.fnamemodify(vim.fn.bufname(cur_buf), ":p:h")
--
-- 	for _, win in ipairs(vim.api.nvim_list_wins()) do
-- 		if win ~= cur_win then
-- 			local buf = vim.api.nvim_win_get_buf(win)
-- 			local dir = vim.fn.fnamemodify(vim.fn.bufname(buf), ":p:h")
-- 			if dir ~= cur_dir then
-- 				nav.smart_close(win)
-- 			end
-- 		end
-- 	end
--
-- 	print("Deleted windows outside the current directory!")
-- end, { silent = true, desc = "Window: close outside windows" })

-- ============================================================================
-- 终端 / 交换文件（原 after/plugin/keymaps.vim 迁移而来）
-- ============================================================================

-- 终端模式 <C-l> 清屏
vim.keymap.set(
	"t",
	"<C-l>",
	[[<C-\><C-n>:call term_sendkeys(0, 'clear' . "\r")<CR>]],
	{ silent = true, desc = "Term: clear screen" }
)

---@return string 展开后的交换文件目录（取 &directory 的第一段）
local function swap_dir()
	local dir = vim.o.directory:gsub("//.*$", ""):gsub(",.*$", "")
	return vim.fn.expand(dir)
end

-- 删除当前文件的交换文件（.swp 及 .swo/.swn/.swm 备选后缀）
local function delete_current_swap()
	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		vim.notify("没有对应的文件路径。", vim.log.levels.WARN)
		return
	end
	local dir = swap_dir()
	local escaped = current_file:gsub("/", "%%")
	local swap_file = dir .. "/" .. escaped .. ".swp"
	if vim.fn.filereadable(swap_file) == 1 then
		if vim.fn.delete(swap_file) == 0 then
			vim.notify("已删除交换文件: " .. swap_file)
			return
		end
		vim.notify("删除失败: " .. swap_file, vim.log.levels.ERROR)
	end
	for _, suffix in ipairs({ ".swo", ".swn", ".swm" }) do
		local try_file = dir .. "/" .. escaped .. suffix
		if vim.fn.filereadable(try_file) == 1 and vim.fn.delete(try_file) == 0 then
			vim.notify("已删除: " .. try_file)
			return
		end
	end
	local actual_swap = vim.v.swapname
	if actual_swap ~= "" and vim.fn.filereadable(actual_swap) == 1 and vim.fn.delete(actual_swap) == 0 then
		vim.notify("已删除: " .. actual_swap)
		return
	end
	vim.notify("未找到交换文件: " .. swap_file, vim.log.levels.WARN)
end

-- 删除所有交换文件
local function delete_all_swaps()
	local dir = swap_dir()
	if vim.fn.isdirectory(dir) == 0 then
		vim.notify("交换文件目录不存在: " .. dir, vim.log.levels.WARN)
		return
	end
	local files = {}
	for _, pat in ipairs({ "**/*.swp", "**/*.swo", "**/*.swn", "**/*.swm" }) do
		vim.list_extend(files, vim.fn.globpath(dir, pat, false, true))
	end
	if #files == 0 then
		vim.notify("未找到交换文件")
		return
	end
	table.sort(files)
	files = vim.fn.uniq(files)
	local count = 0
	for _, f in ipairs(files) do
		if vim.fn.delete(f) == 0 then
			count = count + 1
		end
	end
	vim.notify("已删除 " .. count .. " 个交换文件")
end

vim.keymap.set(
	"n",
	"<leader>csd",
	delete_current_swap,
	{ silent = true, desc = "Swap: 删除当前文件交换文件" }
)
vim.keymap.set("n", "<leader>csD", delete_all_swaps, { silent = true, desc = "Swap: 删除所有交换文件" })
