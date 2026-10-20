-- lua/core/save-panel.lua
-- 未保存 buffer 列表浮窗：逐条保存 / 全部保存 / 跳转。
--
-- 交互（浮窗/按键/刷新）由 core.float-list 提供；本文件只负责行内容与行内动作。
local M = {}

local unsaved = require("core.unsaved")
local float_list = require("core.float-list")

local HELP = {
	{ "<CR>", "保存选中 buffer" },
	{ "a / <C-s>", "保存全部" },
	{ "o / <Tab>", "跳转到该 buffer" },
	{ "j / k", "上下移动" },
	{ "1-9", "直接保存对应行" },
	{ "r", "刷新列表" },
	{ "?", "显示/隐藏本帮助" },
	{ "q / <Esc>", "关闭面板" },
}

---------------------------------------------------------------------
-- 行构造
---------------------------------------------------------------------
local function short_name(path)
	return vim.fn.fnamemodify(path, ":t")
end

local function short_dir(path)
	return vim.fn.fnamemodify(path, ":~:h")
end

local function list_unsaved()
	local list = {}
	for _, r in ipairs(unsaved.list()) do
		if r.writable then
			list[#list + 1] = r
		end
	end
	return list
end

---------------------------------------------------------------------
-- 操作
---------------------------------------------------------------------
local function write_buf(bufnr)
	local ok, err = pcall(function()
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("silent write")
		end)
	end)
	if not ok then
		vim.notify(
			"保存失败: " .. vim.fn.fnamemodify(vim.fn.bufname(bufnr), ":t") .. "\n" .. tostring(err),
			vim.log.levels.ERROR
		)
	end
end

---------------------------------------------------------------------
-- 面板
---------------------------------------------------------------------
local panel
local jump_target

---当前条目里最长的文件名宽度（用于列对齐）
local function name_width()
	local w = 0
	for _, x in ipairs(panel and panel.items or {}) do
		w = math.max(w, vim.fn.strdisplaywidth(short_name(x.name)))
	end
	return w
end -- 待跳转的 buffer（关闭面板后处理）

local function ensure_panel()
	if panel then
		return panel
	end

	panel = float_list.new({
		title = " 未保存 buffer ",
		width = function()
			local width = 44
			for _, r in ipairs(list_unsaved()) do
				local w = vim.fn.strdisplaywidth(short_name(r.name)) + vim.fn.strdisplaywidth(short_dir(r.name)) + 12
				width = math.max(width, w)
			end
			return math.min(width, math.max(20, vim.o.columns - 4))
		end,
		height = function(n)
			return n + 1
		end,
		guard = function(rows)
			return #rows == 0
		end,
		rows = list_unsaved,
		text = function(r)
			local nm = short_name(r.name)
			local pad = string.rep(" ", name_width() - vim.fn.strdisplaywidth(nm))
			local ft = r.ft ~= "" and ("[" .. r.ft .. "]") or ""
			return string.format("● %s%s  %s  %s", nm, pad, short_dir(r.name), ft)
		end,
		highlights = function(r)
			return {
				{ "SaveDotDirty", 0, #"●" },
				{ "Title", 2, 2 + vim.fn.strdisplaywidth(short_name(r.name)) },
			}
		end,
		enter = function(r, _, self)
			write_buf(r.buf)
			self:refresh()
		end,
		on_number = function(r, _, self)
			write_buf(r.buf)
			self:refresh()
		end,
		keymaps = {
			{
				"a",
				function(self)
					for _, r in ipairs(self.items) do
						write_buf(r.buf)
					end
					self:refresh()
				end,
			},
			{
				"<C-s>",
				function(self)
					for _, r in ipairs(self.items) do
						write_buf(r.buf)
					end
					self:refresh()
				end,
			},
			{
				"o",
				function(self)
					local idx = self:current()
					if idx then
						jump_target = self.items[idx].buf
						self:close("jump")
					end
				end,
			},
			{
				"<Tab>",
				function(self)
					local idx = self:current()
					if idx then
						jump_target = self.items[idx].buf
						self:close("jump")
					end
				end,
			},
			{ "r", "refresh" },
		},
		help = HELP,
		help_title = " 未保存 buffer · 按键帮助 ",
		close_keys = { q = "close", ["<Esc>"] = "close" },
		refresh_events = { "BufWritePost", "TextChanged", "TextChangedI", "BufDelete", "BufAdd", "BufUnload" },
		refresh_augroup = "save_panel_refresh",
		on_close = function(reason)
			if reason == "jump" and jump_target then
				local target = jump_target
				jump_target = nil
				if vim.api.nvim_buf_is_valid(target) then
					vim.cmd("buffer " .. target)
				end
			end
		end,
	})

	return panel
end

function M.toggle()
	if panel and not panel:is_open() then
		panel = nil
	end
	ensure_panel():toggle()
end

---注册用户命令
function M.setup()
	vim.api.nvim_create_user_command("SavePanel", function()
		M.toggle()
	end, { desc = "未保存 buffer 列表" })
end

return M
