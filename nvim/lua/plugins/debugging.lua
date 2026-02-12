local common = require("common")

return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            { "igorlfs/nvim-dap-view", opts = {} },
        },
        config = function()
            local dap = require("dap")

            dap.defaults.fallback.switchbuf = "usetab,uselast"

            vim.fn.sign_define(
                "DapBreakpoint",
                { text = "🛑", texthl = "", linehl = "", numhl = "" }
            )

            dap.adapters.lldb = {
                type = "executable",
                command = "/run/current-system/sw/bin/lldb-dap",
                name = "lldb",
            }

            function path_to_rust_binary()
                local handle = io.popen(os.getenv("HOME") .. "/.cargo/bin/t \"Path to Rust binary\"")
                local result = handle:read("*a")
                handle:close()
                return result
            end

            dap.configurations.rust = {
                {
                    name = "Launch",
                    type = "lldb",
                    request = "launch",
                    program = path_to_rust_binary,
                    preLaunchTask = "rust_compile",
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                    args = {},
                },
                -- {
                --     name = "Test",
                --     type = "lldb",
                --     request = "launch",
                --     program = function()
                --         -- TODO: parse `cargo test --no-run --message-format=json`
                --         return "/Users/davidpdrsn/code/dev-tools/test-command/target/debug/deps/test_command-eb9db06ed68b4515"
                --     end,
                --     args = function()
                --         -- TODO: get this using `test-command`
                --         return { "test_one" }
                --     end,
                --     cwd = "${workspaceFolder}",
                --     stopOnEntry = false,
                -- },
            }

            dap.adapters.coreclr_godot = {
                type = "executable",
                command = "netcoredbg",
                args = {
                    "--interpreter=vscode",
                    "--",
                    os.getenv("GODOT_PATH") or "/Applications/Nix Apps/Godot_mono.app/Contents/MacOS/Godot",
                },
            }

            dap.configurations.cs = {
                {
                    type = "coreclr_godot",
                    name = "Build and run",
                    request = "launch",
                    program = os.getenv("HOME") .. "/code/traffic-signal-sim/.godot/mono/temp/bin/Debug/Traffic Signal Sim.dll",
                    preLaunchTask = "cs_compile",
                },
            }

            dap.configurations.go = {
                {
                    type = "go",
                    name = "Attach remote",
                    mode = "remote",
                    request = "attach",
                },
            }

            vim.keymap.set("n", "<leader><up>", dap.step_out, { desc = "Step out" })
            vim.keymap.set("n", "<leader><down>", dap.step_into, { desc = "Step into" })
            vim.keymap.set("n", "<leader><left>", dap.step_back, { desc = "Step back" })
            vim.keymap.set("n", "<leader><right>", dap.step_over, { desc = "Step over" })

            vim.keymap.set("n", "<leader>dr", dap.restart, { desc = "Restart debugger" })

            vim.keymap.set("n", "<leader>dd", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
            vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue debugging" })
        end,
    },
    {
        "igorlfs/nvim-dap-view",
        config = function()
            local dap = require("dap")
            local dv = require("dap-view")

            dv.setup({
                winbar = {
                    show = true,
                    sections = {
                        "scopes",
                        "threads",
                        "watches",
                        "repl",
                    },
                    default_section = "scopes",
                    controls = {
                        enabled = true,
                    },
                },
                windows = {
                    size = 12,
                    position = "below",
                    terminal = {
                        hide = { "go", "lldb", "coreclr_godot" },
                    },
                },
            })

            dap.listeners.before.attach["dap-view-config"] = dv.open
            dap.listeners.before.launch["dap-view-config"] = dv.open
            dap.listeners.before.event_terminated["dap-view-config"] = dv.close
            dap.listeners.before.event_exited["dap-view-config"] = dv.close

            vim.keymap.set("n", "<leader>dC", function()
                dap.disconnect()
            end, { desc = "Disconnect from debugger" })
            vim.keymap.set("n", "<leader>ds", function()
                dap.terminate()
            end, { desc = "Kill debugger" })
        end,
    },
    {
        "stevearc/overseer.nvim",
        config = function()
            local overseer = require("overseer")

            overseer.setup({})

            overseer.register_template({
                name = "rust_compile",
                builder = function(params)
                    return {
                        cmd = { "cargo" },
                        args = { "build", "--all-features" },
                    }
                end,
                condition = {
                    filetype = { "rust" },
                },
            })

            overseer.register_template({
                name = "cs_compile",
                builder = function(params)
                    return {
                        cmd = { "dotnet" },
                        args = { "build" },
                    }
                end,
                condition = {
                    filetype = { "cs" },
                },
            })
        end,
    },
    {
        "m00qek/baleia.nvim",
        config = function()
            -- Get colors working in the logs/repl window of nvim-dap-ui
            -- https://github.com/mfussenegger/nvim-dap/issues/1114#issuecomment-2407914108
            vim.g.baleia = require("baleia").setup()
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "dap-repl",
                callback = function()
                    vim.g.baleia.automatically(vim.api.nvim_get_current_buf())
                end,
            })
        end,
    },
    {
        "leoluz/nvim-dap-go",
        config = function()
            require("dap-go").setup({
                delve = {
                    -- required for "Attach remote"
                    port = "38697",
                },
            })
        end,
    },
    {
        "theHamsta/nvim-dap-virtual-text",
        config = function()
            require("nvim-dap-virtual-text").setup()
        end,
    },
}
