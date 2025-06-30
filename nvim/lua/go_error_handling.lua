-- Go error handling mapping for <leader>e
vim.api.nvim_create_autocmd("FileType", {
    pattern = "go",
    callback = function()
        vim.keymap.set("n", "<leader>e", function()
            local file_path = vim.fn.expand("%:p")
            local line_number = vim.fn.line(".")

            local cmd = string.format(
                "go-insert-error --file %s --line %d",
                vim.fn.shellescape(file_path),
                line_number
            )

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

            -- Insert error handling code at specified line
            if #lines > 0 then
                local insertion_line = tonumber(lines[1])
                if insertion_line then
                    -- Remove the line number from the output
                    table.remove(lines, 1)
                    -- Insert the error handling code at the specified line
                    vim.fn.append(insertion_line - 1, lines)
                    vim.cmd("write")
                end
            end
        end, {
            buffer = true,
            desc = "Insert Go error handling code",
        })
    end,
})
