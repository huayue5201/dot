-- loclist_toggle.lua
local M = {}

-- 切换位置列表窗口的函数
M.toggleLocationList = function()
   -- 获取当前的位置列表
   local locationList = vim.fn.getloclist(0)

   -- 检查是否存在位置列表
   if #locationList == 0 then
      -- 输出通知到消息窗口
      vim.api.nvim_out_write("当前没有loclist窗口\n")
      return
   end

   -- 列出当前的窗口
   local windows = vim.fn.getwininfo()

   -- 检查位置列表窗口是否打开
   local locationListOpen = false
   for _, window in ipairs(windows) do
      if window.loclist == 1 then
         locationListOpen = true
         break
      end
   end

   -- 切换位置列表窗口
   if locationListOpen then
      vim.cmd([[lclose]])
   else
      vim.cmd([[lopen]])
   end
end

return M
