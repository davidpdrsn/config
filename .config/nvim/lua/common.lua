local M = {}

function M.put(...)
    local objects = {}
    for i = 1, select('#', ...) do
        local v = select(i, ...)
        table.insert(objects, vim.inspect(v))
    end
    print(table.concat(objects, '\n'))
    return ...
end

function M.path_to_file()
    bufnr = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_option(bufnr, 'modified') then
        return vim.fn.expand('%') .. " ●"
    else
        return vim.fn.expand('%')
    end
end

function M.filetype()
    if vim.bo.filetype == "rust" then
        return "🦀"
    else
        return vim.bo.filetype
    end
end

return M
