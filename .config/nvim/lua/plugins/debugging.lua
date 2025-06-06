local common = require("common")
local cmap = common.cmap
local nmap = common.nmap
local vmap = common.vmap
local imap = common.imap
local tmap = common.tmap
local leader = common.leader

return {
    {
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            local dap = require("dap")
            local dap_go = require('dap-go')
            local dapui = require("dapui")

            dap.defaults.fallback.switchbuf = 'usetab,uselast'

            vim.fn.sign_define('DapBreakpoint', {text='🛑', texthl='', linehl='', numhl=''})

            local dapui = require("dapui")
            dapui.setup()

            dap.adapters.lldb = {
                type = 'executable',
                command = '/Library/Developer/CommandLineTools/usr/bin/lldb-dap',
                name = 'lldb'
            }

            dap.configurations.rust = {
                {
                    name = 'Launch',
                    type = 'lldb',
                    request = 'launch',
                    program = function()
                        local handle = io.popen("/Users/davidpdrsn/.cargo/bin/t \"Path to Rust binary\"")
                        local result = handle:read("*a")
                        handle:close()
                        return result
                    end,
                    preLaunchTask = "rust_compile",
                    cwd = '${workspaceFolder}',
                    stopOnEntry = false,
                    args = {},
                },
            }

            dap.adapters.godot = {
                type = 'server',
                host = '127.0.0.1',
                port = 6006,
            }

            dap.adapters.coreclr_godot = {
                type = 'executable',
                command = '/usr/local/netcoredbg',
                args = {
                    '--interpreter=vscode',
                    '--',
                    "/Applications/Godot_mono.app/Contents/MacOS/Godot",
                },
            }

            dap.configurations.cs = {
                {
                    type = "coreclr_godot",
                    name = "Build and run",
                    request = "launch",
                    program = "/Users/davidpdrsn/Games/traffic-signal-sim/.godot/mono/temp/bin/Debug/Traffic Signal Sim.dll",
                    preLaunchTask = "cs_compile"
                },
            }

            dap.listeners.before.attach.dapui_config = function()
              dapui.open()
            end
            dap.listeners.before.launch.dapui_config = function()
              dapui.open()
            end
            dap.listeners.before.event_terminated.dapui_config = function()
              dapui.close()
            end
            dap.listeners.before.event_exited.dapui_config = function()
              dapui.close()
            end

            leader("dt", dap_go.debug_test)
            leader("dT", dap_go.debug_last_test)
            leader("dd", dap.toggle_breakpoint)
            leader("dc", dap.continue)
            leader("dC", function()
                dap.disconnect()
                require("dapui").close()
            end)
            leader("dr", dap.restart)
            leader("ds", function()
                dap.terminate()
                require("dapui").close()
            end)
            leader("D", function()
                dapui.close()
                dapui.open()
            end)
            leader("<up>", dap.step_out)
            leader("<down>", dap.step_into)
            leader("<left>", dap.step_back)
            leader("<right>", dap.step_over)
        end,
    },
    {
        "stevearc/overseer.nvim",
        config = function()
            local overseer = require("overseer")

            overseer.setup({
                strategy = {
                    "toggleterm",
                    quit_on_exit = "success",
                    direction = "float"
                }
            })

            overseer.register_template({
                name = "rust_compile",
                builder = function(params)
                    return {
                        cmd = {'cargo'},
                        args = {"build"},
                    }
                end,
                condition = {
                    filetype = {"rust"},
                },
            })

            overseer.register_template({
                name = "cs_compile",
                builder = function(params)
                    return {
                        cmd = {'dotnet'},
                        args = {"build"},
                    }
                end,
                condition = {
                    filetype = {"cs"},
                },
            })
        end,
    },
    {
        "m00qek/baleia.nvim",
        config = function()
            -- Get colors working in the logs/repl window of nvim-dap-ui
            -- https://github.com/mfussenegger/nvim-dap/issues/1114#issuecomment-2407914108
            vim.g.baleia = require("baleia").setup({ })
            vim.api.nvim_create_autocmd({ "FileType" }, {
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
            require('dap-go').setup({
                dap_configurations = {
                    {
                        type = "go",
                        name = "Attach remote",
                        mode = "remote",
                        request = "attach",
                    },
                },
                delve = {
                    -- required for "Attach remote"
                    port = "38697"
                },
            })
        end,
    },
}
