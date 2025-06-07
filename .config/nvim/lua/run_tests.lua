vim.keymap.set("n", "<leader>so", function()
    vim.cmd("source %")
    print("Sourced " .. vim.fn.expand("%"))
end, { desc = "Source current file" })

vim.keymap.set("n", "<leader>t", function()
    print("foo")
end, { desc = "Test mapping" })
