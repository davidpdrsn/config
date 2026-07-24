local M = {}

local function is_empty_scratch_buffer()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    return vim.api.nvim_buf_get_name(bufnr) == ""
        and vim.bo[bufnr].buftype == ""
        and not vim.bo[bufnr].modified
        and #lines == 1
        and lines[1] == ""
end

function M.open_file(filepath, line_number)
    if is_empty_scratch_buffer() then
        vim.cmd.edit({ args = { filepath } })
    else
        vim.cmd.vsplit({ args = { filepath } })
    end

    local line = tonumber(line_number)
    if line then
        local last_line = vim.api.nvim_buf_line_count(0)
        line = math.max(1, math.min(line, last_line))
        vim.api.nvim_win_set_cursor(0, { line, 0 })
    end
end

function M.open_files_base64(filepaths_base64, line_number)
    local filepaths_json = vim.base64.decode(filepaths_base64)
    local filepaths = vim.json.decode(filepaths_json)
    assert(vim.islist(filepaths), "Expected filepaths to decode to a list")

    for _, filepath in ipairs(filepaths) do
        M.open_file(filepath, line_number)
    end
end

return M
