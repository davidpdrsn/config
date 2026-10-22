-- Run with: nvim --headless -u NONE -l nvim/tests/gitbutler.lua
package.path = "nvim/lua/?.lua;" .. package.path
local gitbutler = require("gitbutler")
local original_system = vim.system
local original_notify = vim.notify
local original_expand = vim.fn.expand
local root = "/repo/linked"
local target
local errors
local linked
local reference
local head
local worktrees

vim.fn.expand = function() return root end
vim.notify = function(message) table.insert(errors, message) end
package.loaded.live_diff = { reload = function() return true end }
vim.system = function(cmd, opts)
    assert(opts.cwd == root, "Command must run in the buffer's checkout")
    local output
    local code = 0
    if cmd[1] == "git" then
        if cmd[2] == "symbolic-ref" then
            output = reference or ""
            code = reference and 0 or 1
        elseif cmd[3] == "--show-toplevel" then
            output = root
        elseif cmd[3] == "--path-format=absolute" then
            output = linked and "/repo/.git/worktrees/linked\n/repo/.git\n" or "/repo/.git\n/repo/.git\n"
        elseif cmd[3] == "HEAD" then
            output = head
        else
            error("Unexpected Git command: " .. table.concat(cmd, " "))
        end
    elseif cmd[2] == "status" then
        output = vim.json.encode({
            stacks = {{ branches = {{ commits = {{ cliId = "main", commitId = "main-sha" }} }} }},
            worktrees = worktrees,
        })
    elseif cmd[2] == "squash" then
        assert(cmd[3] == "file:hunk")
        assert(cmd[4] == "--target")
        target = cmd[5]
        output = ""
    else
        error("Unexpected command: " .. table.concat(cmd, " "))
    end
    return { wait = function() return { code = code, stdout = output, stderr = "" } end }
end

local function reset()
    target = nil
    errors = {}
    linked = true
    reference = "refs/heads/topic"
    head = "worktree-sha"
    worktrees = {{
        reference = reference,
        branches = {{ commits = {{ cliId = "worktree", commitId = head }} }},
    }}
end

local function check(expected)
    local result = gitbutler.squash_hunk_id_into_top_commit("file:hunk")
    assert(target == expected, "Unexpected squash target: " .. tostring(target))
    assert(result == (expected ~= nil))
    assert((#errors == 0) == (expected ~= nil))
end

reset()
check("worktree")
reset()
linked = false
check("main")
reset()
worktrees = {}
check(nil)
reset()
reference = "refs/heads/other"
check(nil)
reset()
reference = nil
check(nil)
reset()
worktrees[1].branches[1].commits = {}
check(nil)
reset()
head = "different-sha"
check(nil)

vim.system = original_system
vim.notify = original_notify
vim.fn.expand = original_expand
print("GitButler worktree tests passed (7 cases)")
