-- lua/ui/qf.lua
--[[
quickfix / location list 栈管理（基于 lua/ui/picker.lua）
=========================================================
多次 :grep / :make / :vimgrep 会在后台堆出多个列表，原生只能 :cnewer / :colder
一层层挪。这个模块把它们摊开成一个 picker：

  :QfStack       quickfix 列表栈
  :QfStackLoc    当前窗口的 location list 栈
  <localleader>Q :QfStack

按键：<CR> 切到该层（没开列表窗口就顺手 :copen / :lopen）、<Esc> 关；
<C-x> 清空该层、<C-d> 删除该层。栈深度受 'chistory' 限制（默认 10）。

和 quicker.nvim 的缓冲区视图互补：那边「看全貌 + 上下文折叠」，这边「按标题挑一层」。
]]
local M = {}

local picker = require("ui.picker")

local function file_of(buf)
	local name = vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) or ""
	if name == "" then
		return "[无文件名]"
	end
	return vim.fn.fnamemodify(name, ":~:.")
end

---@param raw table getqflist/getloclist 给的原始条目
local function entry_text(raw)
	local text = (raw.text or ""):gsub("[\r\n]+", " ")
	return ("%-2s %s:%d:%d  %s"):format(raw.type or "", file_of(raw.bufnr), raw.lnum or 0, raw.col or 0, text)
end

---@param kind "qf"|"loc"
local function stack_size(kind, winid)
	local what = { nr = "$" }
	local res = kind == "loc" and vim.fn.getloclist(winid, what) or vim.fn.getqflist(what)
	return res.nr or 0
end

---某一层的属性（nr/id/title/size/idx）
---@param kind "qf"|"loc"
local function list_info(kind, winid, nr)
	-- 注意字段值要用 0：非字符串值是「请求该字段」的开关，用 1 会和真实 id=1 撞车
	local what = { nr = nr, id = 0, title = 0, size = 0, idx = 0 }
	return kind == "loc" and vim.fn.getloclist(winid, what) or vim.fn.getqflist(what)
end

---当前列表的属性
---@param kind "qf"|"loc"
local function current_info(kind, winid)
	local what = { id = 0, nr = 0, title = 0, size = 0 }
	return kind == "loc" and vim.fn.getloclist(winid, what) or vim.fn.getqflist(what)
end

---某一层的条目
local function list_items(kind, winid, nr)
	local what = { nr = nr, items = 0 }
	local res = kind == "loc" and vim.fn.getloclist(winid, what) or vim.fn.getqflist(what)
	return res.items or {}
end

---切到第 nr 层（原生只支持相对移动，算出差值走 :colder/:cnewer）
local function goto_nr(kind, winid, nr)
	local function do_switch()
		local delta = nr - (current_info(kind, winid).nr or nr)
		if delta == 0 then
			return
		end
		-- 列表号越大越新：往小走 = 更旧（colder），往大走 = 更新（cnewer）
		local cmd = kind == "loc" and (delta < 0 and "lolder %d" or "lnewer %d") or (delta < 0 and "colder %d" or "cnewer %d")
		pcall(vim.cmd, cmd:format(math.abs(delta)))
	end
	if kind == "loc" then
		-- :lolder/:lnewer 作用在当前窗口，必须在目标窗口里跑
		pcall(vim.api.nvim_win_call, winid, do_switch)
	else
		do_switch()
	end
end

local function free_all(kind, winid)
	if kind == "loc" then
		vim.fn.setloclist(winid, {}, "f")
	else
		vim.fn.setqflist({}, "f")
	end
end

---整个栈快照（删除某一层只能靠重建：原生 'f' 是清空全部）
local function snapshot(kind, winid)
	local lists = {}
	for nr = 1, stack_size(kind, winid) do
		local info = list_info(kind, winid, nr)
		lists[nr] = { title = info.title, idx = info.idx, items = list_items(kind, winid, nr) }
	end
	return lists
end

---按顺序重建栈（' ' 每次都新建一层并丢弃其后的，所以从旧到新追加即得原顺序）
local function rebuild(kind, winid, lists, cur_nr)
	free_all(kind, winid)
	for _, l in ipairs(lists) do
		local what = { items = l.items, title = l.title, idx = l.idx }
		if kind == "loc" then
			vim.fn.setloclist(winid, {}, " ", what)
		else
			vim.fn.setqflist({}, " ", what)
		end
	end
	if cur_nr then
		goto_nr(kind, winid, math.max(1, math.min(cur_nr, #lists)))
	end
end

---打开栈 picker
---@param opts? { kind? "qf"|"loc", winid? integer }
function M.open(opts)
	opts = opts or {}
	local kind = opts.kind or "qf"
	local winid = opts.winid or vim.api.nvim_get_current_win()
	local label = kind == "loc" and "loclist" or "quickfix"

	---最新的排在最前面，顺便默认选中当前层
	local function refresh()
		local cur = current_info(kind, winid)
		local items = {}
		for nr = stack_size(kind, winid), 1, -1 do
			local info = list_info(kind, winid, nr)
			items[#items + 1] = {
				nr = nr,
				title = info.title,
				size = info.size,
				current = info.id ~= 0 and info.id == cur.id,
			}
		end
		return items
	end

	local items = refresh()
	if #items == 0 then
		vim.notify(("%s 栈是空的"):format(label), vim.log.levels.INFO)
		return
	end

	local function text(it)
		return ("%2d %s %4d  %s"):format(it.nr, it.current and "▸" or " ", it.size, it.title ~= "" and it.title or "[无标题]")
	end

	local function preview(it)
		local out = { ("%s %d：%s（%d 条）"):format(label, it.nr, it.title ~= "" and it.title or "[无标题]", it.size) }
		out[#out + 1] = ""
		local raws = list_items(kind, winid, it.nr)
		for i, raw in ipairs(raws) do
			if i > 200 then
				out[#out + 1] = ("…(还有 %d 条)"):format(#raws - 200)
				break
			end
			out[#out + 1] = entry_text(raw)
		end
		return out
	end

	---切换后如果没开列表窗口就顺手打开，省得再敲 :copen
	local function open_window()
		if kind == "loc" then
			if vim.fn.getloclist(winid, { winid = 0 }).winid == 0 then
				pcall(vim.api.nvim_win_call, winid, function()
					vim.cmd("lopen")
				end)
			end
		elseif vim.fn.getqflist({ winid = 0 }).winid == 0 then
			pcall(vim.cmd, "copen")
		end
	end

	local function clear_list(item, ctx)
		local info = list_info(kind, winid, item.nr)
		if kind == "loc" then
			vim.fn.setloclist(winid, {}, "r", { items = {}, title = info.title, id = info.id })
		else
			vim.fn.setqflist({}, "r", { items = {}, title = info.title })
		end
		vim.notify(("%s %d 已清空"):format(label, item.nr), vim.log.levels.INFO)
		ctx.set_items(refresh())
	end

	local function delete_list(item, ctx)
		local cur_nr = current_info(kind, winid).nr
		local lists = snapshot(kind, winid)
		table.remove(lists, item.nr)
		if #lists == 0 then
			free_all(kind, winid)
			vim.notify(("%s 栈已清空"):format(label), vim.log.levels.INFO)
			ctx.close()
			return
		end
		-- 原来选中的那一层在删除后前移/后移一位，保持跟着它走
		local keep = cur_nr
		if cur_nr == item.nr then
			keep = math.min(item.nr, #lists)
		elseif cur_nr > item.nr then
			keep = cur_nr - 1
		end
		rebuild(kind, winid, lists, keep)
		vim.notify(("%s %d 已删除"):format(label, item.nr), vim.log.levels.INFO)
		ctx.set_items(refresh())
	end

	picker.pick({
		title = label .. " 栈",
		items = items,
		text = text,
		preview = preview,
		actions = {
			{ key = "<C-x>", desc = "清空该层", fn = clear_list },
			{ key = "<C-d>", desc = "删除该层", fn = delete_list },
		},
		on_choose = function(it)
			goto_nr(kind, winid, it.nr)
			vim.schedule(open_window)
		end,
	})
end

function M.setup()
	vim.api.nvim_create_user_command("QfStack", function()
		M.open({ kind = "qf" })
	end, { desc = "切换 / 清理 quickfix 列表栈" })
	vim.api.nvim_create_user_command("QfStackLoc", function()
		M.open({ kind = "loc" })
	end, { desc = "切换 / 清理 location list 栈" })

	vim.keymap.set("n", "<localleader>Q", function()
		M.open({ kind = "qf" })
	end, { desc = "列表: quickfix 栈（切换/清空/删除）" })
end

return M
