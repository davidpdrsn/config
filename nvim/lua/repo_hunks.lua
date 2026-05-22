local M = {}

local function system_list(cmd, opts)
    local result = vim.system(cmd, opts):wait()
    if result.code ~= 0 then
        return nil, vim.trim(result.stderr or result.stdout or "")
    end

    return vim.split(result.stdout or "", "\n", { plain = true, trimempty = true })
end

local function repo_root()
    local cwd = vim.fn.expand("%:p:h")
    if cwd == "" then
        cwd = vim.fn.getcwd()
    end

    local lines, err = system_list(
        { "git", "rev-parse", "--show-toplevel" },
        { cwd = cwd, text = true }
    )
    if not lines then
        return nil, err
    end

    return lines[1]
end

local function parse_start(start)
    local line = tonumber(start)
    if not line or line < 1 then
        return 1
    end

    return line
end

local function collect_hunks(root, pathspec)
    local cmd = { "git", "diff", "HEAD", "--unified=0", "--no-ext-diff", "--relative" }
    if pathspec then
        vim.list_extend(cmd, { "--", pathspec })
    end

    local lines, err = system_list(cmd, {
        cwd = root,
        text = true,
    })
    if not lines then
        return nil, err
    end

    local hunks = {}
    local current_file
    local current_hunk

    for _, line in ipairs(lines) do
        if line:match("^diff %-%-git ") then
            current_file = nil
            current_hunk = nil
        end

        local file = line:match("^%+%+%+ b/(.+)$")
        if file then
            current_file = file
        elseif line == "+++ /dev/null" then
            current_file = nil
            current_hunk = nil
        end

        local old_start, old_count, new_start, new_count, context =
            line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@ ?(.*)$")
        if current_file and old_start and new_start then
            current_hunk = {
                filename = root .. "/" .. current_file,
                path = current_file,
                lnum = parse_start(new_start),
                old_start = old_start,
                old_count = old_count ~= "" and old_count or "1",
                new_start = new_start,
                new_count = new_count ~= "" and new_count or "1",
                context = context,
                header = line,
                lines = {},
                added_lines = {},
                removed_lines = {},
            }
            table.insert(hunks, current_hunk)
        elseif current_hunk and not line:match("^%-%-%- ") and not line:match("^%+%+%+ ") then
            table.insert(current_hunk.lines, line)
            if line:sub(1, 1) == "+" then
                table.insert(current_hunk.added_lines, line:sub(2))
            elseif line:sub(1, 1) == "-" then
                table.insert(current_hunk.removed_lines, line:sub(2))
            end
        end
    end

    return hunks
end

local function display(entry)
    local context = entry.value.context
    if context == "" then
        return string.format("%s:%d  %s", entry.value.path, entry.value.lnum, entry.value.header)
    end

    return string.format("%s:%d  %s", entry.value.path, entry.value.lnum, context)
end

local namespace = vim.api.nvim_create_namespace("repo_hunks_preview")

local function hunk_diff_lines(hunk)
    local lines = {}
    for _, line in ipairs(hunk.removed_lines) do
        table.insert(lines, "-" .. line)
    end
    for _, line in ipairs(hunk.added_lines) do
        table.insert(lines, "+" .. line)
    end
    return lines
end

local function inject_diff(bufnr, entry)
    local hunk = entry.value
    local new_start = tonumber(hunk.new_start) or hunk.lnum
    local new_count = tonumber(hunk.new_count) or 1
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local start_row = math.min(math.max(new_start - 1, 0), line_count)
    local end_row = math.min(start_row + new_count, line_count)
    local diff_lines = hunk_diff_lines(hunk)

    vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, diff_lines)

    for index, line in ipairs(diff_lines) do
        local row = start_row + index - 1
        local hl_group = line:sub(1, 1) == "-" and "GitSignsDeletePreview" or "GitSignsAddPreview"
        vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
            hl_group = hl_group,
            end_row = row + 1,
            end_col = 0,
            hl_eol = true,
        })
    end
end

local function jump_to_hunk(bufnr, winid, entry)
    local line = tonumber(entry.value.new_start) or entry.value.lnum
    vim.schedule(function()
        if not winid or not vim.api.nvim_win_is_valid(winid) then
            return
        end

        local max_line = vim.api.nvim_buf_line_count(bufnr)
        pcall(vim.api.nvim_win_set_cursor, winid, { math.min(math.max(line, 1), max_line), 0 })
        vim.api.nvim_buf_call(bufnr, function()
            vim.cmd("norm! zz")
        end)
    end)
end

local function current_file_pathspec(root)
    local filename = vim.fn.expand("%:p")
    if filename == "" then
        return nil
    end

    if vim.fs and vim.fs.relpath then
        return vim.fs.relpath(root, filename)
    end

    if filename:sub(1, #root + 1) == root .. "/" then
        return filename:sub(#root + 2)
    end

    return nil
end

local function open(pathspec)
    local root, root_err = repo_root()
    if not root then
        vim.notify("Not in a git repo: " .. root_err, vim.log.levels.WARN)
        return
    end

    local hunks, hunks_err = collect_hunks(root, pathspec)
    if not hunks then
        vim.notify("Failed to collect git hunks: " .. hunks_err, vim.log.levels.ERROR)
        return
    end

    if vim.tbl_isempty(hunks) then
        vim.notify("No git hunks")
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local buffer_previewer = require("telescope.previewers.buffer_previewer")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers
        .new({}, {
            prompt_title = "Git hunks",
            finder = finders.new_table({
                results = hunks,
                entry_maker = function(hunk)
                    return {
                        value = hunk,
                        ordinal = hunk.path .. " " .. hunk.header .. " " .. hunk.context,
                        display = display,
                        filename = hunk.filename,
                        lnum = hunk.lnum,
                        col = 1,
                        text = hunk.header,
                    }
                end,
            }),
            sorter = conf.generic_sorter({}),
            previewer = buffer_previewer.new_buffer_previewer({
                title = "Git hunks preview",
                get_buffer_by_name = function(_, entry)
                    return entry.value.filename
                end,
                define_preview = function(self, entry)
                    conf.buffer_previewer_maker(entry.value.filename, self.state.bufnr, {
                        bufname = self.state.bufname,
                        winid = self.state.winid,
                        callback = function(bufnr)
                            inject_diff(bufnr, entry)
                            jump_to_hunk(bufnr, self.state.winid, entry)
                        end,
                    })
                end,
            }),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)

                    vim.cmd.edit(vim.fn.fnameescape(selection.value.filename))
                    vim.api.nvim_win_set_cursor(0, { selection.value.lnum, 0 })
                    vim.cmd.normal({ "zz", bang = true })
                end)

                return true
            end,
        })
        :find()
end

function M.open_current_file()
    local root, root_err = repo_root()
    if not root then
        vim.notify("Not in a git repo: " .. root_err, vim.log.levels.WARN)
        return
    end

    local pathspec = current_file_pathspec(root)
    if not pathspec then
        vim.notify("Current file is not in the git repo", vim.log.levels.WARN)
        return
    end

    open(pathspec)
end

function M.open_repo()
    open()
end

M.open = M.open_repo

return M
