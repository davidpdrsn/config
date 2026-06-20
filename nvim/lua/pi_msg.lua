local M = {}

local function notify(message, level)
    vim.schedule(function()
        vim.notify(message, level, { title = "pi-msg" })
    end)
end

local function current_file()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
        return nil
    end

    return vim.fn.fnamemodify(path, ":.")
end

local function build_current_line_message(input)
    local file = current_file()
    if file == nil then
        return nil, "current buffer has no file"
    end

    local line_number = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_get_current_line()

    return table.concat({
        string.format("%s:%d", file, line_number),
        "",
        "Current line:",
        line,
        "",
        "User prompt:",
        input,
    }, "\n")
end

local function selected_text()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]

    if start_line > end_line or (start_line == end_line and start_col > end_col) then
        start_line, end_line = end_line, start_line
        start_col, end_col = end_col, start_col
    end

    local selection_type = vim.fn.visualmode()
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    if #lines == 0 then
        return nil, nil, nil
    end

    if selection_type ~= "V" then
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
        lines[1] = string.sub(lines[1], start_col)
    end

    return table.concat(lines, "\n"), start_line, end_line
end

local function build_selection_message(input)
    local file = current_file()
    if file == nil then
        return nil, "current buffer has no file"
    end

    local selection, start_line, end_line = selected_text()
    if selection == nil then
        return nil, "no visual selection found"
    end

    return table.concat({
        string.format("%s:%d-%d", file, start_line, end_line),
        "",
        "Selection:",
        selection,
        "",
        "User prompt:",
        input,
    }, "\n")
end

local function send(build_message)
    vim.ui.input({ prompt = "pi-msg " }, function(input)
        if input == nil or input == "" then
            return
        end

        local message, error = build_message(input)
        if message == nil then
            vim.notify(error, vim.log.levels.ERROR, { title = "pi-msg" })
            return
        end

        vim.system({ "pi-msg", message }, { text = true }, function(result)
            if result.code == 0 then
                notify(vim.trim(result.stdout), vim.log.levels.INFO)
                return
            end

            local stderr = vim.trim(result.stderr)
            if stderr == "" then
                stderr = string.format("pi-msg exited with status %d", result.code)
            end
            notify(stderr, vim.log.levels.ERROR)
        end)
    end)
end

function M.send_current_location()
    send(build_current_line_message)
end

function M.send_visual_selection()
    send(build_selection_message)
end

function M.setup()
    vim.keymap.set(
        "n",
        "<leader>pi",
        M.send_current_location,
        { desc = "Send current file/line to pi agent" }
    )
    vim.keymap.set(
        "x",
        "<leader>pi",
        M.send_visual_selection,
        { desc = "Send visual selection to pi agent" }
    )
end

return M
