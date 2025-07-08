vim.api.nvim_create_autocmd("FileType", {
  pattern = { "typescript", "typescriptreact" },
  callback = function()
    vim.keymap.set("n", "<leader>lF", function()
      vim.cmd("silent !prettierd stop")
    end, { buffer = true, desc = "Stop prettierd" })
  end,
})
