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

local function hunk_overlaps_range(hunk, start_line, end_line)
    if hunk.new_count > 0 then
        local hunk_start = hunk.new_start
        local hunk_end = hunk.new_start + hunk.new_count - 1
        return hunk_start <= end_line and start_line <= hunk_end
    end

    local anchor = math.max(hunk.new_start, 1)
    return start_line <= anchor and anchor <= end_line
end

local function indent_block(text)
    return "    " .. text:gsub("\n", "\n    ")
end

local function format_hunk(hunk)
    local lines = {
        string.format(
            "@@ -%d,%d +%d,%d @@",
            hunk.old_start,
            hunk.old_count,
            hunk.new_start,
            hunk.new_count
        ),
    }

    if hunk.id then
        table.insert(lines, string.format("Hunk id: %s", hunk.id))
    end

    for _, line in ipairs(hunk.old_lines or {}) do
        table.insert(lines, "-" .. line)
    end
    for _, line in ipairs(hunk.new_lines or {}) do
        table.insert(lines, "+" .. line)
    end

    return table.concat(lines, "\n")
end

local function live_diff_hunk_at_cursor()
    local ok, live_diff = pcall(require, "live_diff")
    if not ok or not live_diff.is_enabled() then
        return nil
    end

    return live_diff.hunk_at_cursor()
end

local function live_diff_hunks_in_range(start_line, end_line)
    local ok, live_diff = pcall(require, "live_diff")
    if not ok or not live_diff.is_enabled() then
        return {}
    end

    local hunks = {}
    for _, hunk in ipairs(live_diff.get_hunks()) do
        if hunk_overlaps_range(hunk, start_line, end_line) then
            table.insert(hunks, hunk)
        end
    end

    return hunks
end

local function build_hunk_message(input, hunk)
    local file = current_file()
    if file == nil then
        return nil, "current buffer has no file"
    end

    return table.concat({
        "I'm currently reviewing your changes and have a question about this hunk.",
        "",
        file,
        "",
        "Live diff hunk:",
        indent_block(format_hunk(hunk)),
        "",
        "User prompt:",
        input,
    }, "\n")
end

local function build_hunks_message(input, hunks, start_line, end_line)
    local file = current_file()
    if file == nil then
        return nil, "current buffer has no file"
    end

    local parts = {
        "I'm currently reviewing your changes and have a question about these hunks.",
        "",
        string.format("%s:%d-%d", file, start_line, end_line),
        "",
        "Live diff hunks:",
    }

    for index, hunk in ipairs(hunks) do
        if index > 1 then
            table.insert(parts, "")
        end
        table.insert(parts, indent_block(format_hunk(hunk)))
    end

    table.insert(parts, "")
    table.insert(parts, "User prompt:")
    table.insert(parts, input)

    return table.concat(parts, "\n")
end

local function build_current_line_message(input)
    local hunk = live_diff_hunk_at_cursor()
    if hunk ~= nil then
        return build_hunk_message(input, hunk)
    end

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
        indent_block(line),
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

    local hunks = live_diff_hunks_in_range(start_line, end_line)
    if #hunks > 0 then
        return build_hunks_message(input, hunks, start_line, end_line)
    end

    return table.concat({
        string.format("%s:%d-%d", file, start_line, end_line),
        "",
        "Selection:",
        indent_block(selection),
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
