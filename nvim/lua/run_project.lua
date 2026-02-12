local common = require("common")

function run_project()
    vim.cmd("write")

    local wrapped_cmd = common.tmux_wrap("t run")

    if wrapped_cmd.in_tmux then
        vim.fn.jobstart(wrapped_cmd.cmd)
    else
        local original_win_id = vim.api.nvim_get_current_win()
        vim.cmd("botright 20new")
        local buf = vim.api.nvim_get_current_buf()
        local job_id = vim.fn.jobstart("t run", {
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

vim.keymap.set("n", "<leader>R", function()
    run_project()
end, { desc = "Run project" })
