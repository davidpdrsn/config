-- Go error handling mapping for <leader>e
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.keymap.set("n", "<leader>e", function()
      local file_path = vim.fn.expand("%:p")
      local line_number = vim.fn.line(".")
      
      local cmd = string.format("go-insert-error --file %s --line %d", 
                               vim.fn.shellescape(file_path), line_number)
      
      local handle = io.popen(cmd)
      if not handle then
        return
      end
      
      local output = handle:read("*a")
      handle:close()
      
      local lines = vim.split(output, "\n")
      
      -- Remove empty last line if it exists
      if lines[#lines] == "" then
        table.remove(lines)
      end
      
      -- Insert output below current line
      if #lines > 0 then
        local current_line = vim.fn.line(".")
        vim.fn.append(current_line, lines)
      end
    end, { 
      buffer = true, 
      desc = "Insert Go error handling code" 
    })
  end,
})