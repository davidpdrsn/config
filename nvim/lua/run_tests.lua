local M = {}

local prev_test_buffer = nil
local test_command = nil

function set_test_command_with(cmd)
    local handle = io.popen(cmd, 'r')
    local stdout = handle:read("*a")
    handle:close()

    local data, err = vim.json.decode(stdout)
    if err then
        print("Error decoding JSON:", err)
        test_command = nil
        return
    end

    test_command = data
end

function set_test_command()
    local path = vim.api.nvim_buf_get_name(0)

    local cmd = "test-command --file " .. path .. " --line " .. 0
    set_test_command_with(cmd)
end

function set_test_command_with_line()
    local path = vim.api.nvim_buf_get_name(0)
    local line = vim.api.nvim_win_get_cursor(0)[1]

    local cmd = "test-command --file " .. path .. " --line " .. line
    set_test_command_with(cmd)
end

function run_test_command()
    if not test_command then
        vim.cmd("echoerr \"No test command found\"")
        return
    end

    vim.cmd("write")

    local wrapped_cmd = tmux_wrap(test_command.command .. " " .. table.concat(test_command.args, " "))

    if wrapped_cmd.in_tmux then
        vim.fn.jobstart(wrapped_cmd.cmd)
    else
        local original_win_id = vim.api.nvim_get_current_win()
        vim.cmd('botright 20new')
        prev_test_buffer = vim.api.nvim_get_current_buf()
        local job_id = vim.fn.jobstart(
            wrapped_cmd.cmd,
            {
                term = true,
                on_exit = function(_, status)
                    if status == 0 then
                        vim.api.nvim_buf_delete(prev_test_buffer, { force = false })
                        prev_test_buffer = nil
                    end
                end,
                on_stdout = function(_, data, _)
                    vim.schedule(function()
                        -- Move cursor to last line
                        local last_line = vim.api.nvim_buf_line_count(prev_test_buffer)
                        vim.api.nvim_buf_call(prev_test_buffer, function()
                            vim.api.nvim_win_set_cursor(0, { last_line, 0 })
                        end)
                    end)
                end,
            }
        )
        vim.api.nvim_set_current_win(original_win_id)
    end
end

function is_not_in_tmux()
    return os.getenv("TERM_PROGRAM") ~= "tmux"
end

function tmux_wrap(cmd)
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

vim.keymap.set("n", "<leader>rr", function()
    set_test_command()
end)

vim.keymap.set("n", "<leader>rt", function()
    set_test_command_with_line()
end)

vim.keymap.set("n", "<leader>t", function()
    if prev_test_buffer and vim.api.nvim_buf_is_valid(prev_test_buffer) then
        vim.api.nvim_buf_delete(prev_test_buffer, { force = false })
        prev_test_buffer = nil
    else
        run_test_command()
    end
end)

vim.keymap.set("n", "<leader>T", function()
    local original_win_id = vim.api.nvim_get_current_win()
    vim.cmd('botright 20new')
    term_buf = vim.api.nvim_get_current_buf()
    local job_id = vim.fn.jobstart(
        "/Users/davidpdrsn/.cargo/bin/t",
        {
            term = true,
            on_exit = function(_, status)
                if status == 0 then
                    vim.api.nvim_set_current_win(original_win_id)
                    vim.api.nvim_buf_delete(term_buf, { force = false })
                end
            end,
        }
    )
    vim.cmd('startinsert')
end)

M.statusline = function()
    if test_command then
        return test_command.statusline
    else
        return ""
    end
end

return M
