-- lua/core/exec-flow.lua
--[[
执行流锚点（内部模块）
======================
分析一段代码时按「执行顺序」在行尾打编号锚点，纯记忆锚点 + 快速跳转：

    <leader>xa   标记当前行（自动取下一个编号）
    ]x / [x      按编号顺序跳下一/上一个锚点（不是文件顺序）
    <leader>xl   浮窗列出全部锚点（<CR> 跳、d 删、J/K 调序、c 清空）
    <leader>xd   删除当前行的锚点
    <leader>xc   清空全部
    <leader>xq   导出到 quickfix（配合 quicker / nvim-bqf）

设计约定：
  * 位置靠 extmark 存（插入/删除行自动跟随），不存死行号
  * 编号用 virt_text_pos = "right_align" 右对齐到窗口右侧：不挤占代码、
    不与缩进重叠；标签太长会顶开行尾，届时把 label 换成更窄的写法
    （M.opts.label）即可
  * 编号 = 插入顺序，调序后统一重编号并刷新行尾文本
  * 只活在内存里，重开 Neovim 即消失 —— 它要的是「当次分析的顺序感」，
    跨会话的长期追踪交给 todo2 / todo-comments
  * 与 marks.nvim 的分工：marks 管「临时跳点」，本模块管「带顺序的锚点」
]]
local M = {}

local ns = vim.api.nvim_create_namespace("core.exec-flow")
local HL = "ExecFlowLabel"

--- 有序锚点数组：{ { buf, mark }, ... }，下标即执行顺序
local anchors = {}

local DEFAULT_LABEL = function(seq)
	return "⟦" .. seq .. "⟧"
end

----------------------------------------------------------------------
-- 内部工具
----------------------------------------------------------------------

local function ensure_hl()
	vim.api.nvim_set_hl(0, HL, { link = "DiagnosticVirtualTextInfo", default = true })
end

local function label_text(seq)
	return M.opts.label(seq)
end

--- 取锚点当前位置（0-based row）；锚点已随 buffer 失效时返回 nil
local function position(anchor)
	if not vim.api.nvim_buf_is_valid(anchor.buf) then
		return nil
	end
	local pos = vim.api.nvim_buf_get_extmark_by_id(anchor.buf, ns, anchor.mark, {})
	if not pos or #pos == 0 or pos[1] == nil then
		return nil
	end
	return pos[1], pos[2] or 0
end

--- 丢弃 buffer 已消失/锚点已失效的条目
local function prune()
	local kept = {}
	for _, a in ipairs(anchors) do
		if position(a) then
			kept[#kept + 1] = a
		end
	end
	anchors = kept
end

--- 按当前顺序重写所有行尾编号
local function renumber()
	for i, a in ipairs(anchors) do
		local row, col = position(a)
		if row then
			pcall(vim.api.nvim_buf_set_extmark, a.buf, ns, row, 0, {
				id = a.mark,
				virt_text = { { label_text(i), HL } },
				virt_text_pos = "right_align",
			})
		end
	end
end

local function anchor_at_cursor()
	local buf = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	for i, a in ipairs(anchors) do
		local r = position(a)
		if a.buf == buf and r == row then
			return i
		end
	end
	return nil
end

local function filename(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	return name ~= "" and vim.fn.fnamemodify(name, ":~:.") or ("[No Name:" .. buf .. "]")
end

local function jump_to(pos)
	local a = anchors[pos]
	if not a then
		return
	end
	local row, col = position(a)
	if not row then
		prune()
		renumber()
		return
	end
	-- 列表常常是从抽屉/表格里打开的，浮窗一关焦点就落回插件窗口；先在编辑区安顿好
	-- 再切 buffer，免得撞上 'winfixbuf' 报 E1513。
	require("core.navigation.redirect").to_editor(true)
	if vim.api.nvim_get_current_buf() ~= a.buf then
		vim.api.nvim_set_current_buf(a.buf)
	end
	vim.api.nvim_win_set_cursor(0, { row + 1, col })
	pcall(vim.cmd, "normal! zv")
end

----------------------------------------------------------------------
-- 对外操作
----------------------------------------------------------------------

--- 在光标行添加锚点
function M.add()
	ensure_hl()
	prune()
	local buf = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	for _, a in ipairs(anchors) do
		if a.buf == buf and position(a) == row then
			return
		end
	end
	local mark = vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
		virt_text = { { label_text(#anchors + 1), HL } },
		virt_text_pos = "right_align",
	})
	anchors[#anchors + 1] = { buf = buf, mark = mark }
	renumber()
end

--- 删除当前行的锚点
function M.delete()
	local idx = anchor_at_cursor()
	if not idx then
		return
	end
	M.delete_at(idx)
end

--- 删除第 idx 个锚点（1-based）
function M.delete_at(idx)
	local a = anchors[idx]
	if not a then
		return
	end
	if vim.api.nvim_buf_is_valid(a.buf) then
		pcall(vim.api.nvim_buf_del_extmark, a.buf, ns, a.mark)
	end
	table.remove(anchors, idx)
	renumber()
end

--- 清空
function M.clear()
	for _, a in ipairs(anchors) do
		if vim.api.nvim_buf_is_valid(a.buf) then
			pcall(vim.api.nvim_buf_del_extmark, a.buf, ns, a.mark)
		end
	end
	anchors = {}
end

--- 按编号顺序跳转；dir = 1 下一个，-1 上一个
function M.jump(dir)
	prune()
	if #anchors == 0 then
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	local target
	local cur = anchor_at_cursor()
	if cur then
		target = cur + dir
	else
		-- 光标不在锚点上：按「当前文件位置」在顺序表里找相邻项
		for i, a in ipairs(anchors) do
			local r = position(a)
			if r then
				local after = a.buf > buf or (a.buf == buf and r > row)
				if dir == 1 and after then
					target = i
					break
				elseif dir == -1 and not after and not (a.buf == buf and r == row) then
					target = i
				end
			end
		end
	end

	if not target then
		target = dir == 1 and 1 or #anchors
	elseif target < 1 then
		target = #anchors
	elseif target > #anchors then
		target = 1
	end
	jump_to(target)
end

local function panel_parts(it)
	local seq = ("%2d"):format(it.seq)
	return seq, it.file, tostring(it.lnum)
end

local function panel_text(it)
	local seq, file, lnum = panel_parts(it)
	return "  " .. seq .. "  " .. file .. ":" .. lnum .. "  " .. it.text
end

local function panel_highlights(it)
	local seq, file, lnum = panel_parts(it)
	local s_pos = 2
	local f_pos = s_pos + #seq + 2
	local l_pos = f_pos + #file + 1
	return {
		{ "Special", s_pos, s_pos + #seq },
		{ "Comment", f_pos, f_pos + #file },
		{ "Identifier", l_pos, l_pos + #lnum },
	}
end

--- 列出全部锚点（数据视图，浮窗和 quickfix 都用）
local function entries()
	prune()
	local out = {}
	for i, a in ipairs(anchors) do
		local row = position(a)
		if row then
			local lines = vim.api.nvim_buf_get_lines(a.buf, row, row + 1, false)
			out[#out + 1] = {
				seq = i,
				buf = a.buf,
				lnum = row + 1,
				file = filename(a.buf),
				text = (lines[1] or ""):gsub("^%s+", ""),
			}
		end
	end
	return out
end

--- 浮窗列表
function M.panel()
	ensure_hl()
	local items = entries()
	if #items == 0 then
		return
	end

	if not M._list then
		local float_list = require("core.float-list")
		M._list = float_list.new({
			title = " 执行流 ",
			max_height = 20,
			rows = entries,
			text = panel_text,
			highlights = panel_highlights,
			keymaps = {
				{
					"d",
					function(self)
						local it = self.items[self:current() or 0]
						if not it then
							return
						end
						M.delete_at(it.seq)
						self:refresh()
					end,
					"删除",
				},
				{
					"J",
					function(self)
						M.move(self.items[self:current() or 0], 1)
						self:refresh()
					end,
					"下移",
				},
				{
					"K",
					function(self)
						M.move(self.items[self:current() or 0], -1)
						self:refresh()
					end,
					"上移",
				},
				{
					"c",
					function(self)
						M.clear()
						self:refresh()
					end,
					"清空",
				},
			},
			help = {
				{ "<CR>", "跳到锚点" },
				{ "j/k", "移动" },
				{ "d", "删除锚点" },
				{ "J/K", "调整执行顺序" },
				{ "c", "清空全部" },
				{ "q", "关闭" },
			},
			close_when_empty = true,
		})
	end
	-- <CR> 用 seq 跳（items 下标与 seq 一一对应，但删改后重新取一次更稳）
	M._list.opts.enter = function(it)
		M._list:close("jump")
		jump_to(it.seq)
	end
	M._list:toggle()
end

--- 调整第 idx 个锚点的顺序（dir = 1 下移 / -1 上移）
function M.move_by_idx(idx, dir)
	if not idx then
		return
	end
	local to = idx + dir
	if to < 1 or to > #anchors then
		return
	end
	anchors[idx], anchors[to] = anchors[to], anchors[idx]
	renumber()
end

--- 接受条目（含 seq）而不是下标
function M.move(entry, dir)
	if not entry then
		return
	end
	M.move_by_idx(entry.seq, dir)
end

--- 导出到 quickfix
function M.qf()
	local items = entries()
	if #items == 0 then
		return
	end
	local list = {}
	for _, it in ipairs(items) do
		list[#list + 1] = {
			filename = vim.api.nvim_buf_get_name(it.buf),
			lnum = it.lnum,
			col = 1,
			text = ("[%d] %s"):format(it.seq, it.text),
		}
	end
	vim.fn.setqflist({}, " ", { title = "Exec Flow", items = list })
	vim.cmd("copen")
end

----------------------------------------------------------------------
-- 命令与状态
----------------------------------------------------------------------

M.opts = { label = DEFAULT_LABEL }

function M.setup(opts)
	M.opts = vim.tbl_extend("force", M.opts, opts or {})
	ensure_hl()
	vim.api.nvim_create_user_command("ExecFlowAdd", M.add, { desc = "执行流: 标记当前行" })
	vim.api.nvim_create_user_command("ExecFlowList", M.panel, { desc = "执行流: 列出锚点" })
	vim.api.nvim_create_user_command("ExecFlowClear", M.clear, { desc = "执行流: 清空锚点" })
	vim.api.nvim_create_user_command("ExecFlowQf", M.qf, { desc = "执行流: 导出到 quickfix" })

	vim.api.nvim_create_autocmd("BufWipeout", {
		group = vim.api.nvim_create_augroup("core_exec_flow", { clear = true }),
		callback = function(ev)
			-- 直接删掉指向被 wipe buffer 的条目，保持编号连续
			local kept = {}
			for _, a in ipairs(anchors) do
				if a.buf ~= ev.buf then
					kept[#kept + 1] = a
				end
			end
			if #kept ~= #anchors then
				anchors = kept
				renumber()
			end
		end,
	})
end

-- 测试/调试用
M._anchors = function()
	return anchors
end

return M
