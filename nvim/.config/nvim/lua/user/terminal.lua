-- user/terminal.lua
-- user/terminate.lua

local function Term()
  local terminal_buffer_number = vim.fn.bufnr("term://")
  local terminal_window_number = vim.fn.bufwinnr("term://")
  local window_count = vim.fn.winnr("$")

  if terminal_window_number > 0 and window_count > 1 then
    vim.fn.execute(terminal_window_number .. "wincmd c")
  elseif terminal_buffer_number > 0 and terminal_buffer_number ~= vim.fn.bufnr("%") then
    vim.fn.execute("sb " .. terminal_buffer_number)
  elseif terminal_buffer_number == vim.fn.bufnr("%") then
    vim.fn.execute("bprevious | sb " .. terminal_buffer_number .. " | wincmd p")
  else
    vim.fn.execute("sp term://zsh")
  end
end

local M = {}

function M.setup()
  -- 创建 Term 命令
  vim.api.nvim_create_user_command("Term", Term, {
    desc = "Open terminal window",
  })

  -- 设置键映射
  vim.keymap.set({ "n", "t", "i" }, "<c-\\>", vim.cmd.Term, { noremap = true, silent = true })
  vim.keymap.set("t", "<esc>", "<C-\\><C-n>", { noremap = true, silent = true })
end

return M
