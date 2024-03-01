-- https://github.com/rcarriga/nvim-dap-ui

return {
   "rcarriga/nvim-dap-ui",
   requires = { "mfussenegger/nvim-dap" },
   keys = {
      { "<leader>du", desc = "调试模式" },
   },
   config = function()
      require("dapui").setup()
      local dap, dapui = require("dap"), require("dapui")
      dap.listeners.before.attach.dapui_config = function()
         dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
         dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
         dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
         dapui.close()
      end
      vim.keymap.set("n", "<leader>du", "<cmd>lua require'dapui'.toggle()<cr>")
   end,
}
