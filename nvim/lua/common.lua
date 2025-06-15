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

function M.lsp_format_leader_command(pattern)
    vim.api.nvim_create_autocmd('FileType', {
      pattern = pattern,
      callback = function(ev)
        vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        local opts = { buffer = ev.buf }
        vim.keymap.set('n', '<space>lf', function()
          vim.lsp.buf.format { async = true }
        end, opts)
      end,
    })
end

function M.custom_format_leader_command(pattern, command)
    vim.api.nvim_create_autocmd("FileType", {
        pattern = pattern,
        callback = function(ev)
            local opts = { buffer = true }
            local f = function()
                vim.api.nvim_command('write')
                local path = vim.api.nvim_buf_get_name(0)
                vim.fn.system(command(path))
                local view = vim.fn.winsaveview()
                vim.cmd('edit')
                vim.fn.winrestview(view)
            end
            vim.keymap.set('n', '<space>lf', f, opts)
        end,
    })
end

function is_not_in_tmux()
    return os.getenv("TERM_PROGRAM") ~= "tmux"
end

function M.tmux_wrap(cmd)
    if is_not_in_tmux() then
        return { in_tmux = false, cmd = cmd }
    end

    local handle = io.popen("tmux list-panes -F '#{pane_index} #{pane_current_command}'", 'r')
    local stdout = handle:read("*a")
    handle:close()

    for _, line in pairs(vim.split(stdout, '\n')) do
        if line ~= "" then
            local words = vim.split(line, ' ')
            local n = words[1]
            local pane_cmd = words[2]
            if pane_cmd == "zsh" then
                return {
                    in_tmux = true,
                    cmd = "tmux send-keys -t " .. n .. " \"" .. cmd .. "\" Enter",
                }
            end
        end
    end

    return { in_tmux = false, cmd = cmd }
end

return M
