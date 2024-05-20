-- https://github.com/mfussenegger/nvim-lint

return {
  "mfussenegger/nvim-lint",
  ft = { "make" },
  config = function()
    require('lint').linters_by_ft = {
      make = { "checkmake" },
    }

    vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
      callback = function()
        require("lint").try_lint()
      end,
    })
  end
}
