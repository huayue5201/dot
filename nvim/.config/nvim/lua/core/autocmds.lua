-- File: ~/dotfiles/nvim/.config/nvim/lua/core/autocmds.lua

vim.api.nvim_create_autocmd("BufWritePre", {
	group = vim.api.nvim_create_augroup("RemoveTrailingWhitespace", { clear = true }),
	desc = "保存前自动删除行尾空格",
	callback = function()
		vim.cmd([[%s/\s\+$//e]])
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

local nav = require("user.navigation")

-- ============================
-- 通用函数：为当前 buffer 应用快捷键映射
-- ============================
local function apply_keymaps()
	local ft = vim.bo.filetype
	local bt = vim.bo.buftype
	local bufname = vim.fn.bufname("%")
	local applied = vim.b.keymaps_applied or {}

	-- 确定当前窗口的类型标识（优先级：filetype > buftype > 特殊匹配）
	local buf_type = ft ~= "" and ft or bt

	for key, type_configs in pairs(nav.buf_keymaps) do
		-- 跳过已映射的按键
		if not applied[key] then
			-- 获取配置（精确匹配 或 dap-repl 特殊处理）
			local config = type_configs[buf_type]

			if not config and bufname:match("dap%-repl") then
				config = type_configs["dap-repl"]
			end

			-- 如果有配置，应用映射
			if config and config.cmd then
				local cmd = config.cmd
				local desc = config.desc or ("映射: " .. key)

				-- 根据命令类型创建映射函数
				local map_func = (cmd == "next_error" or cmd == "prev_error")
						and function()
							nav.dispatch_command(cmd)
						end
					or function()
						nav.dispatch_command(cmd)
					end

				vim.keymap.set("n", key, map_func, {
					buffer = true,
					silent = true,
					noremap = true,
					nowait = true,
					desc = desc,
				})

				applied[key] = true
			end
		end
	end

	vim.b.keymaps_applied = applied
end

-- ============================
-- 注册自动命令
-- ============================

-- 快捷键映射：当进入 buffer 或切换文件类型时应用
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	desc = "根据配置表自动应用窗口快捷键",
	callback = apply_keymaps,
})

-- Buffer 设置
local buffer_settings = nav.settings
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("CustomBufferSettings", { clear = true }),
	desc = "根据配置表自动应用 buffer 设置",
	callback = function(args)
		local buf = args.buf
		local ft = vim.bo[buf].filetype
		local bt = vim.bo[buf].buftype
		local kind = (ft ~= "" and ft) or bt

		if buffer_settings[kind] and buffer_settings[kind].setup then
			buffer_settings[kind].setup()
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
