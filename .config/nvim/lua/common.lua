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

function make_map_fn(mode)
    return function(mapping, what_to_do, options)
        options = options or {}
        if options.noremap == nil then
            options.noremap = true
        end

        vim.keymap.set(mode, mapping, what_to_do, options)
    end
end

M.cmap = make_map_fn("c")
M.nmap = make_map_fn("n")
M.vmap = make_map_fn("v")
M.imap = make_map_fn("i")
M.tmap = make_map_fn("t")

function M.leader(mapping, what_to_do, options)
    M.nmap("<leader>" .. mapping, what_to_do, options)
end

return M
