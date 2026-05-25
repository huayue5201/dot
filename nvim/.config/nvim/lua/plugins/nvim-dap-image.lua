-- https://gitlab.com/david_wright/nvim-dap-image

return{
  url = "https://gitlab.com/david_wright/nvim-dap-image",
	event = "VeryLazy",
  -- GitHub mirror: "dav1d-wright/nvim-dap-image"
  dependencies = { "mfussenegger/nvim-dap", "3rd/image.nvim" },
  config = function()
    require("nvim-dap-image").setup({
  -- Directory for temporary image files (defaults to system temp dir)
  tmp_dir = vim.uv.os_tmpdir() .. "/nvim-dap-image",

  -- Floating window settings
  window = {
    width_pct = 0.6,    -- percentage of editor width
    height_pct = 0.6,   -- percentage of editor height
    border = "rounded", -- border style
  },

  -- Close all image viewers when the debug session ends
  auto_close_on_terminate = true,

  -- Delete temp files when a viewer is closed
  auto_cleanup_temp = true,

  -- Additional user-defined extractors (see Custom Extractors below)
  extractors = {},
})

vim.keymap.set("n", "<leader>dli", "<cmd>DapImageView<cr>", { desc = "View variable as image" })
  end,
}

