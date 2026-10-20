-- File: nvim/.config/nvim/lua/core/autocmds.lua

-- 进入真实文件时，清理残留的空 [No Name] buffer（nvim 无参启动/旧 tab 留下的）
local function is_empty_scratch(b)
	return vim.api.nvim_buf_is_valid(b)
		and vim.api.nvim_buf_get_name(b) == ""
		and vim.bo[b].buftype == ""
		and not vim.bo[b].modified
		and vim.api.nvim_buf_line_count(b) == 1
		and vim.api.nvim_buf_get_lines(b, 0, -1, false)[1] == ""
end

-- 白名单：这些是侧栏/UI buffer，进入它们绝不能触发清理。
-- 否则在侧栏开分屏的过程中删掉空 buffer，会把侧栏挤成全窗口
-- （实测 <leader>ef 打开 neo-tree 时会发生）。
local cleanup_skip_filetypes = {
	"alpha",
	"dashboard",
	"grug-far",
	"help",
	"lazy",
	"neo-tree",
	"NvimTree",
	"sqmeow-drawer",
	"todo2drawer",
	"Trouble",
}

-- buffer 是否正在某个窗口里显示；正在显示的空 buffer 不删，避免窗口布局被破坏
local function is_buffer_visible(b)
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == b then
			return true
		end
	end
	return false
end

vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("DropEmptyBuffers", { clear = true }),
	desc = "进入命名文件后删除残留的无名空 buffer",
	callback = function(args)
		-- 会话恢复中（mksession / `:restart`）：session 脚本自己在 prologue 末尾执行
		-- `bwipe <启动空 buffer>`，这里抢先删掉它会让那句 bwipe 报 E517。
		if vim.g.SessionLoad == 1 then
			return
		end
		-- 只对「真实文件」触发：无名、特殊 buftype、白名单侧栏一律跳过
		if
			vim.api.nvim_buf_get_name(args.buf) == ""
			or vim.bo[args.buf].buftype ~= ""
			or vim.tbl_contains(cleanup_skip_filetypes, vim.bo[args.buf].filetype)
		then
			return
		end
		for _, b in ipairs(vim.api.nvim_list_bufs()) do
			if b ~= args.buf and not is_buffer_visible(b) and is_empty_scratch(b) then
				vim.api.nvim_buf_delete(b, { force = false })
			end
		end
	end,
})

-- Ensure that the binary spl file is up-to-date with the source add file
vim.api.nvim_create_autocmd("FocusGained", {
	pattern = "*",
	callback = function()
		local config_path = vim.fn.stdpath("config") -- Get Neovim's config path
		local add_file = config_path .. "/spell/en.utf-8.add"
		local spl_file = config_path .. "/spell/en.utf-8.add.spl"

		if vim.fn.filereadable(add_file) == 1 then
			local add_mtime = vim.fn.getftime(add_file) -- Get modification time of .add file
			local spl_mtime = vim.fn.getftime(spl_file) -- Get modification time of .add.spl file

			-- Run mkspell! only if .add is newer than .add.spl or .add.spl doesn't exist
			if add_mtime > spl_mtime or spl_mtime == -1 then
				vim.cmd("silent! mkspell! " .. spl_file .. " " .. add_file)
			end
		end
	end,
})

-- Scale windows with the screen, which Nvim only offers as `wincmd =`.

local aug = vim.api.nvim_create_augroup("Resize", { clear = true })

---@type table<integer, table<integer, [number, number]>>
local tab_ratios = {}
local cols, lines = vim.o.columns, vim.o.lines
local applying = false

---@param tab integer
---@return integer[] wins, integer width, integer height
local function layout(tab)
	local wins = {}
	local top, left = math.huge, math.huge
	local bottom, right = 0, 0

	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
		if vim.api.nvim_win_get_config(win).relative == "" then
			local pos = vim.api.nvim_win_get_position(win)
			wins[#wins + 1] = win
			top = math.min(top, pos[1])
			left = math.min(left, pos[2])
			bottom = math.max(bottom, pos[1] + vim.api.nvim_win_get_height(win))
			right = math.max(right, pos[2] + vim.api.nvim_win_get_width(win))
		end
	end

	return wins, math.max(1, right - left), math.max(1, bottom - top)
end

local function capture_ratios()
	if applying or vim.o.columns ~= cols or vim.o.lines ~= lines then
		return
	end

	local tab = vim.api.nvim_get_current_tabpage()
	local wins, width, height = layout(tab)
	local ratios = {}
	for _, win in ipairs(wins) do
		ratios[win] = {
			vim.api.nvim_win_get_width(win) / width,
			vim.api.nvim_win_get_height(win) / height,
		}
	end
	tab_ratios[tab] = ratios
end

capture_ratios()

vim.api.nvim_create_autocmd({ "WinResized", "TabEnter" }, {
	group = aug,
	callback = capture_ratios,
})

vim.api.nvim_create_autocmd("VimResized", {
	group = aug,
	callback = function()
		applying = true
		for tab, ratios in pairs(tab_ratios) do
			if vim.api.nvim_tabpage_is_valid(tab) then
				local wins, width, height = layout(tab)
				for _, win in ipairs(wins) do
					local ratio = ratios[win]
					if ratio then
						pcall(
							vim.api.nvim_win_resize,
							win,
							math.max(1, math.floor(ratio[1] * width + 0.5)),
							math.max(1, math.floor(ratio[2] * height + 0.5))
						)
					end
				end
			else
				tab_ratios[tab] = nil
			end
		end
		cols, lines = vim.o.columns, vim.o.lines
		vim.schedule(function()
			applying = false
		end)
	end,
})

vim.cmd([[
		function! YankShift()
		for i in range(9, 1, -1)
		call setreg(i, getreg(i - 1))
		endfor
		endfunction

		autocmd TextYankPost * if v:event.operator == 'y' | call YankShift() | endif
		autocmd TextYankPost * silent! lua vim.hl.hl_op {higroup='Visual', timeout=300}
		autocmd TextPutPost  * silent! lua vim.hl.hl_op {higroup='Visual', timeout=300}
]])

vim.api.nvim_create_autocmd("InsertEnter", {
	callback = function()
		if vim.v.hlsearch == 1 then
			vim.v.hlsearch = 0
		end
	end,
})
