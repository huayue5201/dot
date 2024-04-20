-- https://github.com/ibhagwan/fzf-lua

return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = { "<leader>ff", "<leader>fb", "<leader>fo", "<leader>g" },
  config = function()
    -- calling `setup` is optional for customization
    require("fzf-lua").setup({
      winopts = {
        preview = { default = 'bat_native' }
      },
      -- fzf_opts = { ['--ansi'] = false },
      files = {
        git_icons = false,
        file_icons = false,
      }
    })
    -- 文件检索
    vim.keymap.set("n", "<leader>ff", "<cmd>lua require('fzf-lua').files()<CR>", { silent = true })
    vim.keymap.set("n", "<leader>fb", "<cmd>lua require('fzf-lua').buffers()<CR>", { silent = true })
    vim.keymap.set("n", "<leader>fo", "<cmd>lua require('fzf-lua').oldfiles()<CR>", { silent = true })
    vim.keymap.set("n", "<leader>fg", "<cmd>lua require('fzf-lua').grep()<CR>", { silent = true })
    vim.keymap.set("v", "<leader>fg", "<cmd>lua require('fzf-lua').grep_visual()<CR>", { silent = true })
  end
}
