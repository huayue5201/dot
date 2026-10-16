-- resession 扩展：把「一 tab 一工作区」的 buffer 归属存进会话文件。
-- 这样隐藏缓冲区（不在任何窗口里的）也能在恢复会话后回到正确的 tab。
-- 逻辑本体在 lua/core/tab_workspace.lua。
local M = {}

function M.on_save()
	return require("core.tab_workspace").export()
end

function M.on_post_load(data)
	require("core.tab_workspace").import(data)
end

return M
