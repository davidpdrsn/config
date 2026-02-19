local M = {}

function M.put(...)
    local objects = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        table.insert(objects, vim.inspect(v))
    end
    print(table.concat(objects, "\n"))
    return ...
end

function M.path_to_file()
    bufnr = vim.api.nvim_get_current_buf()
    if vim.api.nvim_buf_get_option(bufnr, "modified") then
        return vim.fn.expand("%") .. " ●"
    else
        return vim.fn.expand("%")
    end
end

function M.filetype()
    if vim.bo.filetype == "rust" then
        return "🦀"
    else
        return vim.bo.filetype
    end
end

function M.lsp_format_leader_command(pattern)
    vim.api.nvim_create_autocmd("FileType", {
        pattern = pattern,
        callback = function(ev)
            vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
            vim.keymap.set("n", "<space>lf", function()
                vim.lsp.buf.format({ async = true })
            end, { buffer = ev.buf, desc = "Format" })
        end,
    })
end

function M.custom_format_leader_command(pattern, command)
    vim.api.nvim_create_autocmd("FileType", {
        pattern = pattern,
        callback = function(ev)
            local opts = { buffer = true, desc = "Format" }
            local f = function()
                vim.api.nvim_command("write")
                local path = vim.api.nvim_buf_get_name(0)
                vim.fn.system(command(path))
                local view = vim.fn.winsaveview()
                vim.cmd("edit")
                vim.fn.winrestview(view)
            end
            vim.keymap.set("n", "<space>lf", f, opts)
        end,
    })
end

function is_not_in_vmux()
    return os.getenv("VMUX") ~= "true"
end

function M.vmux_wrap(cmd)
    if is_not_in_vmux() then
        return { in_vmux = false, cmd = cmd }
    end

    return { in_vmux = true, cmd = "vmux terminal add test --ephemeral --current-project -- direnv exec . " .. cmd }
end

function is_not_in_tmux()
    return os.getenv("TERM_PROGRAM") ~= "tmux"
end

function M.tmux_wrap(cmd)
    if is_not_in_tmux() then
        return { in_tmux = false, cmd = cmd }
    end

    local handle = io.popen("tmux list-panes -F '#{pane_index} #{pane_current_command}'", "r")
    local stdout = handle:read("*a")
    handle:close()

    for _, line in pairs(vim.split(stdout, "\n")) do
        if line ~= "" then
            local words = vim.split(line, " ")
            local n = words[1]
            local pane_cmd = words[2]
            if pane_cmd == "fish" then
                return {
                    in_tmux = true,
                    cmd = "tmux send-keys -t "
                        .. n
                        .. " \""
                        .. cmd:gsub("\\", "\\\\"):gsub("\"", "\\\"")
                        .. "\" Enter",
                }
            end
        end
    end

    return { in_tmux = false, cmd = cmd }
end

function M.tmux_run(cmd)
    local wrapped_cmd = M.tmux_wrap(cmd)

    if wrapped_cmd.in_tmux then
        vim.fn.jobstart(wrapped_cmd.cmd)
    else
        local original_win_id = vim.api.nvim_get_current_win()
        vim.cmd("botright 20new")
        local buf = vim.api.nvim_get_current_buf()
        local job_id = vim.fn.jobstart(cmd, {
            term = true,
            on_exit = function(_, status)
                if status == 0 then
                    vim.api.nvim_buf_delete(buf, { force = false })
                end
            end,
            on_stdout = function(_, data, _)
                vim.schedule(function()
                    -- Move cursor to last line
                    local last_line = vim.api.nvim_buf_line_count(buf)
                    vim.api.nvim_buf_call(buf, function()
                        vim.api.nvim_win_set_cursor(0, { last_line, 0 })
                    end)
                end)
            end,
        })
        vim.api.nvim_set_current_win(original_win_id)
    end
end

return M
