-- https://github.com/saccarosium/neomarks

return {
   "saccarosium/neomarks",
   keys = {
      { "<leader>a", [[<cmd>lua require("neomarks").mark_file()<cr>]], desc = "标记文件" },
      { "<leader>oa", [[<cmd>lua require("neomarks").menu_toggle()<cr>]], desc = "标记列表" },
   },
   config = function()
      require("neomarks").setup({
         storagefile = vim.fn.stdpath("data") .. "/neomarks.json",
         menu = {
            title = "Neomarks",
            title_pos = "center",
            border = "rounded",
            width = 60,
            height = 10,
         },
      })
   end,
}
