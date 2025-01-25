-- Helper function to create augroups more efficiently
local function create_augroup(name, events)
  local group = vim.api.nvim_create_augroup(name, { clear = true })
  for _, event in ipairs(events) do
    vim.api.nvim_create_autocmd(event[1], {
      group = group,
      desc = event[2],
      callback = event[3],
    })
  end
end

-- 清理尾部空白字符
vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "保存文件时移除末尾的空白字符",
  group = vim.api.nvim_create_augroup("cleanSpace", { clear = true }),
  pattern = "*",
  command = "%s/\\s\\+$//e",
})

-- 禁用特定 buffer 中的状态列
create_augroup("disableStatusColumn", {
  { "FileType", "禁用特定buffer内的状态列", function()
    local special_filetypes = { "aerial", "qf", "help", "man" }
    if vim.tbl_contains(special_filetypes, vim.bo.filetype) then
      vim.wo.statuscolumn = " "
    end
  end }
})

-- 记住最后的光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
  desc = "记住最后的光标位置",
  group = vim.api.nvim_create_augroup("LastPlace", { clear = true }),
  pattern = "*",
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- 禁止换行时延续注释符号
vim.api.nvim_create_autocmd("FileType", {
  desc = "换行不要延续注释符号",
  pattern = "*",
  callback = function()
    vim.opt.formatoptions:remove({ "o", "r" })
  end,
})

-- 在特定文件类型中用 q 关闭窗口
create_augroup("closeWithQ", {
  { "FileType", "用q关闭窗口", function()
    local filetypes = { "help", "startuptime", "qf", "lspinfo", "checkhealth" }
    if vim.tbl_contains(filetypes, vim.bo.filetype) then
      vim.api.nvim_buf_set_keymap(0, "n", "q", ":close<CR>", { noremap = true, silent = true })
    end
  end },
  { "FileType", "用q关闭man窗口", function()
    if vim.bo.filetype == "man" then
      vim.api.nvim_buf_set_keymap(0, "n", "q", ":quit<CR>", { noremap = true, silent = true })
    end
  end }
})

-- 仅在活动窗口显示光标线
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
  desc = "仅在活动窗口显示光标线",
  pattern = "*",
  command = "set cursorline",
  group = vim.api.nvim_create_augroup("CursorLineGroup", { clear = true })
})
vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
  desc = "仅在活动窗口显示光标线",
  pattern = "*",
  command = "set nocursorline",
  group = vim.api.nvim_create_augroup("CursorLineGroup", { clear = true })
})

-- 高亮文本复制
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("YankHighlightRestoreCursor", { clear = true }),
  pattern = "*",
  callback = function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    if #vim.v.event.regcontents <= 100 then
      vim.highlight.on_yank()
    end
    if vim.v.event.operator == "y" then
      vim.defer_fn(function() vim.api.nvim_win_set_cursor(0, cursor) end, 10)
    end
  end,
})

-- 强制注释符号包括空格
create_augroup("commentstring_spaces", {
  { "CursorHold", "确保注释符号后有空格", function(args)
    local cs = vim.bo[args.buf].commentstring
    vim.bo[args.buf].commentstring = cs:gsub("(%S)%%s", "%1 %%s"):gsub("%%s(%S)", "%%s %1")
  end },
  { "FileType", "强制设置注释符号格式", function()
    -- 在特定文件类型中强制注释格式（可以扩展）
    local cs = vim.bo.commentstring
    vim.bo.commentstring = cs:gsub("(%S)%%s", "%1 %%s"):gsub("%%s(%S)", "%%s %1")
  end }
})

-- 支持从 SSH 复制内容到本地剪贴板
vim.api.nvim_create_autocmd("TermRequest", {
  desc = "支持从 SSH 复制内容到本地剪贴板",
  callback = function(args)
    local data = args.data:match("\027]52;c;(.+)")
    if not data then return end
    local osc52 = string.format("\27]52;c;%s\7", data)
    if os.getenv("TMUX") or os.getenv("TERM"):match("^tmux") or os.getenv("TERM"):match("^screen") then
      osc52 = string.format("\27Ptmux;\27%s\27\\", osc52)
    end
    if vim.loop.fs_stat("/dev/fd/2") then
      vim.fn.writefile({ osc52 }, "/dev/fd/2", "b")
    else
      vim.fn.chansend(vim.v.stderr, osc52)
    end
  end,
})

-- Toggle Quickfix 和 Location List
vim.api.nvim_create_user_command("ToggleQuickfix", function()
  -- 检查是否有 Quickfix 窗口
  local quickfixOpen = false
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.quickfix == 1 then
      quickfixOpen = true
      break
    end
  end

  if quickfixOpen then
    vim.cmd("cclose")
  else
    vim.cmd("copen")
  end
end, { desc = "Toggle Quickfix window" })

vim.api.nvim_create_user_command("ToggleLoclist", function()
  -- 检查是否有 Location List 窗口
  local locationListOpen = false
  for _, win in ipairs(vim.fn.getwininfo()) do
    if win.loclist == 1 then
      locationListOpen = true
      break
    end
  end
  -- 如果有 Location List 窗口，则切换打开或关闭
  if locationListOpen then
    vim.cmd("lclose")
  else
    -- 如果没有 Location List, 提示用户没有内容
    local locationList = vim.fn.getloclist(0)
    if #locationList == 0 then
      vim.api.nvim_err_write("当前没有 loclist 可用\n")
    else
      vim.cmd("lopen")
    end
  end
end, { desc = "Toggle Location List" })

vim.api.nvim_create_user_command("BufferDelete", function()
  ---@diagnostic disable-next-line: missing-parameter
  local file_exists = vim.fn.filereadable(vim.fn.expand("%p"))
  local modified = vim.api.nvim_get_option_value("modified", { scope = "local", buf = 0 })
  if file_exists == 0 and modified then
    local user_choice = vim.fn.input("The file is not saved, whether to force delete? Press enter or input [y/n]:")
    if user_choice == "y" or string.len(user_choice) == 0 then
      vim.cmd("bd!")
    end
    return
  end
  local force = not vim.bo.buflisted or vim.bo.buftype == "nofile"
  vim.cmd(force and "bd!" or string.format("bp | bd! %s", vim.api.nvim_get_current_buf()))
end, { desc = "Delete the current Buffer while maintaining the window layout" })

-- 自动命令: 进入插入模式时清除搜索高亮
create_augroup("ibhagwan/ToggleSearchHL", {
  { "InsertEnter", "进入插入模式时清除搜索高亮", function() vim.cmd("nohlsearch") end },
  { "CursorMoved", "光标移动时更新搜索高亮", function()
    local view, rpos = vim.fn.winsaveview(), vim.fn.getpos(".")
    vim.cmd(string.format("silent! keepjumps go%s",
      (vim.fn.line2byte(view.lnum) + view.col + 1 - (vim.v.searchforward == 1 and 2 or 0))))
    local ok, _ = pcall(function()
      if vim.fn.search(vim.fn.getreg("/"), "W") == 0 then
        return false
      end
      return true
    end)
    local insearch = ok and (function()
      local npos = vim.fn.getpos(".")
      return npos[2] == rpos[2] and npos[3] == rpos[3]
    end)()
    vim.fn.winrestview(view)
    if not insearch then
      vim.schedule(function() vim.cmd("nohlsearch") end)
    end
  end }
})
