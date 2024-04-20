-- https://github.com/rebelot/terminal.nvim

return {
  'rebelot/terminal.nvim',
  keys = { "<C-\\>", "<leader>ts", "<leader>tr", "<leader>tk" },
  config = function()
    -- 加载 terminal.nvim 并设置
    require("terminal").setup()

    -- 导入 terminal.mappings 模块
    local term_map = require("terminal.mappings")

    -- 设置自定义键映射
    vim.keymap.set({ "n", "x" }, "<leader>ts", term_map.operator_send, { expr = true })  -- 在普通和可视模式下，发送运算符
    vim.keymap.set({ "n", "t", "i" }, "<C-\\>", term_map.toggle)  -- 在普通、可视和插入模式下，切换终端
    vim.keymap.set("n", "<leader>tr", term_map.run)  -- 在普通模式下，运行终端
    vim.keymap.set("n", "<leader>tk", term_map.kill)  -- 在普通模式下，关闭终端
    vim.keymap.set("n", "]t", term_map.cycle_next)  -- 在普通模式下，切换到下一个终端
    vim.keymap.set("n", "[t", term_map.cycle_prev)  -- 在普通模式下，切换到上一个终端

    -- 设置终端相关键映射
    vim.api.nvim_set_keymap('t', '<esc>', '<CMD>Term<CR>', { noremap = true, silent = true })  -- 在终端模式下，按下 <Esc> 键，切换到普通模式
    vim.api.nvim_set_keymap('t', '<C-h>', '<C-\\><C-n><C-w>h', { noremap = true, silent = true })  -- 在终端模式下，按下 <C-h> 键，切换到左侧窗口
    vim.api.nvim_set_keymap('t', '<C-j>', '<C-\\><C-n><C-w>j', { noremap = true, silent = true })  -- 在终端模式下，按下 <C-j> 键，切换到下方窗口
    vim.api.nvim_set_keymap('t', '<C-k>', '<C-\\><C-n><C-w>k', { noremap = true, silent = true })  -- 在终端模式下，按下 <C-k> 键，切换到上方窗口
    vim.api.nvim_set_keymap('t', '<C-l>', '<C-\\><C-n><C-w>l', { noremap = true, silent = true })  -- 在终端模式下，按下 <C-l> 键，切换到右侧窗口

    -- 当窗口进入、缓冲区窗口进入或终端打开时，自动进入插入模式
    vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "TermOpen" }, {
      callback = function(args)
        if vim.startswith(vim.api.nvim_buf_get_name(args.buf), "term://") then
          vim.cmd("startinsert")
        end
      end,
    })
  end
}
