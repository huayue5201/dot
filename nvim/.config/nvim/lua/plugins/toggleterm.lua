-- https://github.com/akinsho/toggleterm.nvim

return {
   "akinsho/toggleterm.nvim",
   keys = { "<C-\\>", "<C-w>\\" },
   cmd = { "ToggleTerm", "ToggleTermToggleAll" },
   version = "*",
   config = function()
      require("toggleterm").setup({
         size = function(term)
            if term.direction == "horizontal" then
               return 20
            elseif term.direction == "vertical" then
               return vim.o.columns * 0.4
            end
         end,
         open_mapping = [[<c-\>]],
         shade_terminals = true, -- 加深终端背景色
         hide_numbers = true, -- 隐藏数字列
         direction = "horizontal",
         winbar = {
            enabled = true,
            name_formatter = function(term) --  term: Terminal
               return term.name
            end,
         },
      })

      vim.keymap.set(
         { "n", "t", "i" },
         "<C-w>\\",
         '<cmd>lua  require("utils.term_all").init_or_toggle() <cr>',
         { desc = "全部终端", noremap = true, silent = true }
      )

      function _G.set_terminal_keymaps()
         local opts = { buffer = 0 }
         vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
         vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
         vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
         vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
         vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
         vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
         vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
      end

      -- if you only want these mappings for toggle term use term://*toggleterm#* instead
      vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
   end,
}
