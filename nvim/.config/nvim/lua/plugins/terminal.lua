-- https://github.com/rebelot/terminal.nvim

return {
  'rebelot/terminal.nvim',
  keys = { "<c-\\>", "<leader>tr", "<leader>ts" },
  config = function()
    require("terminal").setup()
    -- require("terminal").current_term_index()

    local term_map = require("terminal.mappings")
    -- 使用 operator_send 函数将选择的文本发送到终端
    vim.keymap.set({ "n", "x" }, "<leader>ts", term_map.operator_send, { expr = true })
    -- 使用 toggle 函数在 Normal 模式下打开或关闭终端
    vim.keymap.set({ "n", "i", "t" }, "<C-\\>", term_map.toggle)
    -- 使用 run 函数在 Normal 模式下运行新的终端
    vim.keymap.set("n", "<leader>tr", term_map.run)
    -- 使用 kill 函数在 Normal 模式下关闭当前终端
    vim.keymap.set("n", "<leader>tk", term_map.kill)
    -- 使用 cycle_next 函数在 Normal 模式下切换到下一个终端
    vim.keymap.set("n", "]t", term_map.cycle_next)
    -- 使用 cycle_prev 函数在 Normal 模式下切换到上一个终端
    vim.keymap.set("n", "[t", term_map.cycle_prev)

    -- 自动插入模式
    vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "TermOpen" }, {
      callback = function(args)
        if vim.startswith(vim.api.nvim_buf_get_name(args.buf), "term://") then
          vim.cmd("startinsert")
        end
      end,
    })
    vim.api.nvim_create_autocmd("TermOpen", {
      command = [[setlocal nonumber norelativenumber winhl=Normal:NormalFloat]]
    })
  end
}
