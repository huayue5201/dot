-- resession 扩展：把「一 tab 一工作区」的 buffer 归属存进会话文件。
-- 这样隐藏缓冲区（不在任何窗口里的）恢复后也能回到正确的 tab。
-- 逻辑本体在 lua/feat/tab_workspace/session.lua。
local M = {}

---@param opts? { tabpage?: integer }
function M.on_save(opts)
	return require("feat.tab_workspace.session").export(opts and opts.tabpage)
end

--- 此时 resession 仍处于 loading 状态（relist 会被 util.resession_loading() 挡掉），
--- 所以这里只记录归属，真正重排 buflisted 在 post_load 钩子里做。
function M.on_post_load(data)
	require("feat.tab_workspace.session").on_session_restore(data)
end

return M
