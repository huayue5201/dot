-- https://github.com/linrongbin16/fzfx.nvim

return {
  "linrongbin16/fzfx.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>ff", desc = "文件检索" },
    { "<leader>fg", desc = "字符检索" },
    { "<leader>fb", desc = "buffer检索" },
    -- { "<leader>fo", desc = "历史文件检索" },
    -- { "<leader>fm", desc = "标签检索" },
  },
  config = function()
    require("fzfx").setup()
    vim.keymap.set(
      "n",
      "<space>ff",
      "<cmd>FzfxFiles<cr>",
      { silent = true, noremap = true, desc = "Find files" }
    )
    -- live grep
    vim.keymap.set(
      "n",
      "<space>fg",
      "<cmd>FzfxLiveGrep<cr>",
      { silent = true, noremap = true, desc = "Live grep" }
    )
    -- by visual select
    vim.keymap.set(
      "x",
      "<space>fg",
      "<cmd>FzfxLiveGrep visual<cr>",
      { silent = true, noremap = true, desc = "Live grep" }
    )
    -- by args
    vim.keymap.set(
      "n",
      "<space>fb",
      "<cmd>FzfxBuffers<cr>",
      { silent = true, noremap = true, desc = "Find buffers" }
    )
  end,
}
