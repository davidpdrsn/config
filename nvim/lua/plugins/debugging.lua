local common = require("common")

return {
    {
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            local dap = require("dap")
            local dap_go = require("dap-go")
            local dapui = require("dapui")

            dap.defaults.fallback.switchbuf = "usetab,uselast"

            vim.fn.sign_define(
                "DapBreakpoint",
                { text = "🛑", texthl = "", linehl = "", numhl = "" }
            )

            local dapui = require("dapui")
            dapui.setup()

            dap.adapters.lldb = {
                type = "executable",
                command = "/Library/Developer/CommandLineTools/usr/bin/lldb-dap",
                name = "lldb",
            }

            dap.configurations.rust = {
                {
                    name = "Launch",
                    type = "lldb",
                    request = "launch",
                    program = function()
                        local handle =
                            io.popen("/Users/davidpdrsn/.cargo/bin/t \"Path to Rust binary\"")
                        local result = handle:read("*a")
                        handle:close()
                        return result
                    end,
                    preLaunchTask = "rust_compile",
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                    args = {},
                },
            }

            dap.adapters.godot = {
                type = "server",
                host = "127.0.0.1",
                port = 6006,
            }

            dap.adapters.coreclr_godot = {
                type = "executable",
                command = "netcoredbg",
                args = {
                    "--interpreter=vscode",
                    "--",
                    "/Applications/Godot_mono.app/Contents/MacOS/Godot",
                },
            }

            dap.configurations.cs = {
                {
                    type = "coreclr_godot",
                    name = "Build and run",
                    request = "launch",
                    program = "/Users/davidpdrsn/code/traffic-signal-sim/.godot/mono/temp/bin/Debug/Traffic Signal Sim.dll",
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

            function set_mappings()
                vim.keymap.set("n", "<leader><up>", dap.step_out, { desc = "Step out" })
                vim.keymap.set("n", "<leader><down>", dap.step_into, { desc = "Step into" })
                vim.keymap.set("n", "<leader><left>", dap.step_back, { desc = "Step back" })
                vim.keymap.set("n", "<leader><right>", dap.step_over, { desc = "Step over" })

                vim.keymap.set("n", "<leader>dC", function()
                    dap.disconnect()
                    require("dapui").close()
                end, { desc = "Disconnect from debugger" })
                vim.keymap.set("n", "<leader>dr", dap.restart, { desc = "Restart debugger" })
                vim.keymap.set("n", "<leader>ds", function()
                    dap.terminate()
                    require("dapui").close()
                end, { desc = "Kill debugger" })
                vim.keymap.set("n", "<leader>D", function()
                    dapui.close()
                    dapui.open()
                end, { desc = "Toggle debugger UI" })
            end

            function del_mappings()
                vim.keymap.del("n", "<leader><up>")
                vim.keymap.del("n", "<leader><down>")
                vim.keymap.del("n", "<leader><left>")
                vim.keymap.del("n", "<leader><right>")

                vim.keymap.del("n", "<leader>dC")
                vim.keymap.del("n", "<leader>dr")
                vim.keymap.del("n", "<leader>ds")
                vim.keymap.del("n", "<leader>D")
            end

            dap.listeners.before.attach.dapui_config = function()
                set_mappings()
                dapui.open()
            end
            dap.listeners.before.launch.dapui_config = function()
                set_mappings()
                dapui.open()
            end
            dap.listeners.before.event_terminated.dapui_config = function()
                del_mappings()
                dapui.close()
            end
            dap.listeners.before.event_exited.dapui_config = function()
                del_mappings()
                dapui.close()
            end

            vim.keymap.set("n", "<leader>dd", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
            vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue debugging" })
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
                        args = { "build" },
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
