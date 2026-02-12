local common = require("common")

local M = {}

local prev_test_buffer = nil
local test_command = nil

local function run_test_command(cmd)
    if prev_test_buffer and vim.api.nvim_buf_is_valid(prev_test_buffer) then
        vim.api.nvim_buf_delete(prev_test_buffer, { force = false })
        prev_test_buffer = nil
        return
    end

    vim.cmd("write")

    local wrapped_cmd =
        common.tmux_wrap(cmd.command .. " " .. table.concat(cmd.args, " "))

    if wrapped_cmd.in_tmux then
        vim.fn.jobstart(wrapped_cmd.cmd)
    else
        local original_win_id = vim.api.nvim_get_current_win()
        vim.cmd("botright 20new")
        prev_test_buffer = vim.api.nvim_get_current_buf()
        local job_id = vim.fn.jobstart(wrapped_cmd.cmd, {
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
        })
        vim.api.nvim_set_current_win(original_win_id)
    end
end

local function json_shell(cmd)
    local handle = io.popen(cmd, "r")
    local stdout = handle:read("*a")
    handle:close()

    local data, err = vim.json.decode(stdout)
    if err then
        print("Error decoding JSON:", err)
        test_command = nil
        return
    end

    return data
end

local function set_test_command()
    local path = vim.api.nvim_buf_get_name(0)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local cmd = "test-command --file " .. path .. " --line " .. line
    test_command = json_shell(cmd)
end

local function test_file()
    if not test_command then
        set_test_command()
    end
    run_test_command(test_command.file)
end

local function test_line()
    if not test_command then
        set_test_command()
    end
    run_test_command(test_command.file_and_line)
end

local function test_file_debugger()
    if not test_command then
        set_test_command()
    end
    run_test_command(test_command.file_debugger)
end

local function test_line_debugger()
    if not test_command then
        set_test_command()
    end
    run_test_command(test_command.file_and_line_debugger)
end

local function chain(f, g)
    return function()
        f()
        g()
    end
end

vim.keymap.set("n", "<leader>t", test_file, { desc = "Run test file" })

vim.keymap.set("n", "<leader>T", chain(set_test_command, test_file), { desc = "Run+set test file" })

vim.keymap.set("n", "<leader>k", test_line, { desc = "Run test line" })

vim.keymap.set("n", "<leader>K", chain(set_test_command, test_line), { desc = "Run+set test line" })

vim.keymap.set("n", "<leader>dt", test_file_debugger, { desc = "Run test file, in debugger" })

vim.keymap.set(
    "n",
    "<leader>DT",
    chain(set_test_command, test_file_debugger),
    { desc = "Run+set test file, in debugger" }
)

vim.keymap.set("n", "<leader>dk", test_line_debugger, { desc = "Run test line, in debugger" })

vim.keymap.set(
    "n",
    "<leader>DK",
    chain(set_test_command, test_line_debugger),
    { desc = "Run+set test line, in debugger" }
)

return M
