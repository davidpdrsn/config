-- Load before configuring smart-splits: setup() returns options for that plugin.
local M = {}

function M.setup()
    if not vim.env.MUX_SOCKET or not vim.env.MUX_PANE then
        return {}
    end
    -- Modern Neovim runs its TUI separately from the Lua/core process.
    local editor_pid = vim.fn.getpid()
    for _, ui in ipairs(vim.api.nvim_list_uis()) do
        local client = vim.api.nvim_get_chan_info(ui.chan).client
        if client and client.name == "nvim-tui" and client.attributes and client.attributes.pid then
            editor_pid = tonumber(client.attributes.pid) or editor_pid
            break
        end
    end
    local pid = tostring(editor_pid)
    local function command(args)
        local argv = { "mux", "--socket", vim.env.MUX_SOCKET, "pane" }
        vim.list_extend(argv, args)
        -- Wait for registration/navigation so subsequent keys see the updated state.
        local result = vim.system(argv, { text = true }):wait()
        if result.code ~= 0 then
            vim.schedule(function()
                vim.notify("mux: " .. (result.stderr or "command failed"), vim.log.levels.WARN)
            end)
        end
    end
    command({ "register-editor", "--target", vim.env.MUX_PANE, "--pid", pid })
    local group = vim.api.nvim_create_augroup("MuxNavigation", { clear = true })
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
            command({ "register-editor", "--target", vim.env.MUX_PANE, "--pid", pid, "--remove" })
        end,
    })
    return {
        multiplexer_integration = false,
        at_edge = function(ctx)
            command({ "focus", "--from", vim.env.MUX_PANE, "--direction", ctx.direction })
        end,
    }
end

return M
