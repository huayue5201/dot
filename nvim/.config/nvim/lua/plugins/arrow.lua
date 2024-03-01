-- https://github.com/otavioschwanck/arrow.nvim

return {
   "otavioschwanck/arrow.nvim",
   keys = { ";", "H", "L", "<leader>aa" },
   config = function()
      require("arrow").setup({
         show_icons = true,
         leader_key = ";", -- Recommended to be a single key
         separate_by_branch = true,
      })
      vim.keymap.set("n", "H", require("arrow.persist").previous)
      vim.keymap.set("n", "L", require("arrow.persist").next)
      vim.keymap.set("n", "<leader>aa", require("arrow.persist").toggle)
   end,
}
