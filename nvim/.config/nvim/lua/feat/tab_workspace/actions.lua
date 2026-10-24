-- 工作区动作：关闭 buffer/窗口、切换根目录、保存会话、新建/关闭/切换工作区。
local M = {}

local util = require("feat.tab_workspace.util")
local ownership = require("feat.tab_workspace.ownership")

--- 关闭 buffer：若它仍显示在其他 tab 的窗口里（同一 buffer 被多个 tab 共享），
--- 只从当前 tab 移除，并把归属转给仍在显示它的 tab（切回去仍可见），不 bdelete。
--- 否则直接 bdelete!（BufDelete 会触发 forget）。
---@param bufnr integer
function M.close_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	local cur = vim.api.nvim_get_current_tabpage()
	local other
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		if tab ~= cur then
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
				if vim.api.nvim_win_get_buf(win) == bufnr then
					other = tab
					break
				end
			end
		end
		if other then
			break
		end
	end
	if not other and vim.bo[bufnr].modified then
		local name = vim.api.nvim_buf_get_name(bufnr)
		name = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t")
		if
			vim.fn.confirm(string.format("%s 有未保存的修改，仍要关闭？", name), "&关闭\n&取消", 2)
			~= 1
		then
			return
		end
	end
	if other then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(cur)) do
			if vim.api.nvim_win_get_buf(win) == bufnr then
				vim.api.nvim_win_call(win, function()
					vim.cmd("enew")
				end)
			end
		end
		if vim.api.nvim_buf_is_valid(bufnr) and util.is_workspace_buf(bufnr) then
			ownership.claim(other, bufnr)
		else
			ownership.forget(bufnr)
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.bo[bufnr].buflisted = false
			end
		end
		ownership.relist()
	else
		vim.cmd(("bdelete! %d"):format(bufnr))
	end
	vim.cmd("redrawtabline")
end

--- 设置当前 tab 的工作区根目录（neo-tree 会经 DirChanged 自动跟随）
---@param dir? string
function M.set_root(dir)
	dir = vim.fn.expand(dir or vim.fn.getcwd())
	vim.cmd.tcd({ args = { dir } })
end

--- 交互式设置当前 tab 根目录
function M.prompt_root()
	local cur = vim.fn.getcwd()
	vim.ui.input({ prompt = "工作区根目录: ", default = cur, completion = "dir" }, function(input)
		if input and input ~= "" then
			M.set_root(input)
		end
	end)
end

--- 保存当前会话（若有）
function M.save_session()
	local ok, resession = pcall(require, "resession")
	if not ok then
		return
	end
	local current = resession.get_current()
	if current then
		resession.save(current, { notify = false })
	else
		resession.save_all({ notify = false })
	end
end

--- 新建工作区：保存当前会话 + 开新 tab + 设置根目录
---@param dir? string
function M.new_workspace(dir)
	M.save_session()
	vim.cmd("tabnew")
	if dir then
		M.set_root(dir)
	else
		M.prompt_root()
	end
end

--- 关闭工作区：关闭当前 tab 后保存会话
--- 注意顺序：先保存会把「刚关掉的 tab」继续留在会话文件里，下次 load 又复活。
function M.close_workspace()
	if #vim.api.nvim_list_tabpages() > 1 then
		vim.cmd("tabclose")
	end
	M.save_session()
end

--- 在当前 tab 与上一个 tab 之间切换
function M.alternate()
	local last_tab = ownership.get_last_tab()
	if last_tab and vim.api.nvim_tabpage_is_valid(last_tab) and last_tab ~= vim.api.nvim_get_current_tabpage() then
		vim.api.nvim_set_current_tabpage(last_tab)
	end
end

return M
