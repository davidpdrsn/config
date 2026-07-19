local M = {}

local but = "/Users/davidpdrsn/code/gitbutler/gitbutler-git/target/release/but"

local function notify_error(message)
    vim.notify(message, vim.log.levels.ERROR, { title = "GitButler rub" })
end

local function system(cmd, opts)
    local result = vim.system(cmd, opts):wait()
    if result.code ~= 0 then
        return nil, vim.trim(result.stderr or result.stdout or "")
    end

    return result.stdout or ""
end

local function system_json(cmd, opts)
    local stdout, err = system(cmd, opts)
    if not stdout then
        return nil, err
    end

    local ok, decoded = pcall(vim.json.decode, stdout)
    if not ok then
        return nil, "Failed to parse JSON: " .. decoded
    end

    return decoded
end

local function repo_root()
    local cwd = vim.fn.expand("%:p:h")
    if cwd == "" then
        cwd = vim.fn.getcwd()
    end

    local stdout, err = system(
        { "git", "rev-parse", "--show-toplevel" },
        { cwd = cwd, text = true }
    )
    if not stdout then
        return nil, err
    end

    return vim.trim(stdout)
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

local function parse_count(count)
    if count == "" then
        return 1
    end

    return tonumber(count) or 1
end

local function cursor_is_in_hunk(cursor_line, hunk)
    if hunk.new_lines == 0 then
        return cursor_line == hunk.new_start
    end

    return cursor_line >= hunk.new_start and cursor_line <= hunk.new_start + hunk.new_lines - 1
end

local function current_cursor_hunk(root, pathspec)
    local stdout, err = system(
        { "git", "diff", "HEAD", "--unified=0", "--no-ext-diff", "--relative", "--", pathspec },
        { cwd = root, text = true }
    )
    if not stdout then
        return nil, err
    end

    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local current_hunk

    for _, line in ipairs(vim.split(stdout, "\n", { plain = true })) do
        local old_start, old_count, new_start, new_count =
            line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
        if old_start and new_start then
            if current_hunk then
                break
            end

            local hunk = {
                path = pathspec,
                old_start = tonumber(old_start),
                old_lines = parse_count(old_count),
                new_start = tonumber(new_start),
                new_lines = parse_count(new_count),
                diff_lines = {},
            }

            if cursor_is_in_hunk(cursor_line, hunk) then
                current_hunk = hunk
            end
        elseif
            current_hunk
            and not line:match("^diff %-%-git ")
            and not line:match("^%-%-%- ")
            and not line:match("^%+%+%+ ")
        then
            table.insert(current_hunk.diff_lines, line)
        end
    end

    if not current_hunk then
        return nil, "Cursor is not inside a git hunk"
    end

    return current_hunk
end

local function most_recent_commit(root)
    local status, err = system_json({ but, "status", "--format", "json" }, { cwd = root, text = true })
    if not status then
        return nil, err
    end

    local latest
    for _, stack in ipairs(status.stacks or {}) do
        for _, branch in ipairs(stack.branches or {}) do
            for _, commit in ipairs(branch.commits or {}) do
                if
                    commit.commitId
                    and commit.commitId ~= ""
                    and (not latest or (commit.createdAt or "") > (latest.createdAt or ""))
                then
                    latest = commit
                end
            end
        end
    end

    if not latest then
        return nil, "No commit found in GitButler status"
    end

    return latest
end

local function diff_text_matches(diff_text, cursor_hunk)
    for _, line in ipairs(cursor_hunk.diff_lines) do
        if line ~= "" and not diff_text:find(line, 1, true) then
            return false
        end
    end

    return true
end

local function hunk_matches(change, diff_hunk, cursor_hunk)
    if change.path ~= cursor_hunk.path then
        return false
    end

    local old_start = tonumber(diff_hunk.oldStart)
    local old_lines = tonumber(diff_hunk.oldLines)
    local new_start = tonumber(diff_hunk.newStart)
    local new_lines = tonumber(diff_hunk.newLines)

    local exact_match = old_start == cursor_hunk.old_start
        and old_lines == cursor_hunk.old_lines
        and new_start == cursor_hunk.new_start
        and new_lines == cursor_hunk.new_lines
    if exact_match then
        return true
    end

    local overlaps = new_start
        and new_lines
        and cursor_hunk.new_start >= new_start
        and cursor_hunk.new_start <= new_start + math.max(new_lines - 1, 0)
    return overlaps and diff_text_matches(diff_hunk.diff or "", cursor_hunk)
end

local function find_hunk_cli_id(root, cursor_hunk)
    local diff, err = system_json({ but, "diff", "--format", "json" }, { cwd = root, text = true })
    if not diff then
        return nil, err
    end

    local matches = {}
    for _, change in ipairs(diff.changes or {}) do
        if change.id and change.diff and change.diff.type == "patch" then
            for _, diff_hunk in ipairs(change.diff.hunks or {}) do
                if hunk_matches(change, diff_hunk, cursor_hunk) then
                    table.insert(matches, change.id)
                end
            end
        end
    end

    if #matches == 0 then
        return nil, "Could not find a matching GitButler hunk id"
    end

    if #matches > 1 then
        return nil, "Found multiple matching GitButler hunk ids"
    end

    return matches[1]
end

local function rub(root, source_cli_id, target_cli_id)
    local output, err = system(
        { but, "rub", "--format", "json", source_cli_id, target_cli_id },
        { cwd = root, text = true }
    )
    if not output then
        return nil, err
    end

    return output
end

local function discard(root, cli_id)
    local output, err = system({ but, "discard", cli_id }, { cwd = root, text = true })
    if not output then
        return nil, err
    end

    return output
end

local function run_but_simple(command)
    local root, root_err = repo_root()
    if not root then
        notify_error("Not in a git repo: " .. root_err)
        return false
    end

    local _, err = system({ but, command }, { cwd = root, text = true })
    if err then
        notify_error(err)
        return false
    end

    vim.cmd("checktime")

    vim.notify("Ran but " .. command, vim.log.levels.INFO, { title = "GitButler" })
    return true
end

function M.undo()
    return run_but_simple("undo")
end

function M.redo()
    return run_but_simple("redo")
end

function M.open_file(filepath, line_number)
    package.loaded.gitbutler_open = nil
    return require("gitbutler_open").open_file(filepath, line_number)
end

local function current_hunk_cli_id()
    local root, root_err = repo_root()
    if not root then
        notify_error("Not in a git repo: " .. root_err)
        return false
    end

    local pathspec = current_file_pathspec(root)
    if not pathspec then
        notify_error("Current file is not in the git repo")
        return false
    end

    local hunk, hunk_err = current_cursor_hunk(root, pathspec)
    if not hunk then
        notify_error(hunk_err)
        return false
    end

    local hunk_cli_id, hunk_cli_err = find_hunk_cli_id(root, hunk)
    if not hunk_cli_id then
        notify_error(hunk_cli_err)
        return false
    end

    return root, hunk_cli_id
end

function M.rub_hunk_id_into_most_recent_commit(hunk_cli_id)
    if not hunk_cli_id or hunk_cli_id == "" then
        notify_error("Missing hunk id")
        return false
    end

    local root, root_err = repo_root()
    if not root then
        notify_error("Not in a git repo: " .. root_err)
        return false
    end

    local commit, commit_err = most_recent_commit(root)
    if not commit then
        notify_error(commit_err)
        return false
    end

    local _, rub_err = rub(root, hunk_cli_id, commit.commitId)
    if rub_err then
        notify_error(rub_err)
        return false
    end

    vim.cmd("checktime")
    local ok, reloaded = pcall(function()
        return require("live_diff").reload()
    end)
    if not ok then
        notify_error("Failed to reload live_diff: " .. reloaded)
    elseif not reloaded then
        notify_error("live_diff was not enabled for the current buffer")
    end

    vim.notify(
        string.format("Rubbed %s into %s", hunk_cli_id, commit.commitId),
        vim.log.levels.INFO,
        { title = "GitButler rub" }
    )
    return true
end

function M.discard_current_hunk()
    local root, hunk_cli_id = current_hunk_cli_id()
    if not root then
        return false
    end

    local _, discard_err = discard(root, hunk_cli_id)
    if discard_err then
        notify_error(discard_err)
        return false
    end

    vim.cmd("checktime")

    vim.notify(
        string.format("Discarded %s", hunk_cli_id),
        vim.log.levels.INFO,
        { title = "GitButler rub" }
    )
    return true
end

return M
