local common = require("common")
local cmap = common.cmap
local nmap = common.nmap
local vmap = common.vmap
local imap = common.imap
local tmap = common.tmap
local leader = common.leader

return {
    -- highlight other occurances of words
    { 'RRethy/vim-illuminate' },
    -- easy lsp config
    {
        'neovim/nvim-lspconfig',
        config = function()
            local lspconfig = require('lspconfig')

            lspconfig.rust_analyzer.setup({
                settings = {
                    ['rust-analyzer'] = {
                        inlayHints = {
                            chainingHints = true,
                        },
                        cargo = {
                            features = "all",
                            autoreload = true,
                            buildScripts = {
                                enable = true,
                            }
                        },
                        checkOnSave = {
                            overrideCommand = {
                                "cargo",
                                "clippy",
                                "--all-features",
                                "--tests",
                                "--message-format=json",
                                "--all-targets",
                                "--target-dir",
                                "/Users/davidpdrsn/.rust-analyzer-target-dir",
                                "--workspace",
                            },
                            enable = true,
                        },
                        completion = {
                            autoimport = {
                                enable = true,
                            },
                            postfix = {
                                enable = true,
                            },
                        },
                        diagnostics = {
                            disabled = {"macro-error"},
                        },
                        procMacro = {
                            enable = true,
                            attributes = {
                                enable = true,
                            },
                        },
                        rustcSource = "discover",
                    }
                }
            })

            vim.lsp.enable({
                'rust_analyzer',
                'csharp_ls',
                'ts_ls',
                'gopls',
                'eslint',
                'postgres_lsp',
            })
        end,
    },
    -- icons in lsp suggestions window
    { "onsails/lspkind.nvim" },
    -- more lsp code actions
    {
        "nvimtools/none-ls.nvim",
        config = function()
            local null_ls = require("null-ls")

            null_ls.setup({
                sources = {
                    null_ls.builtins.code_actions.impl,
                    null_ls.builtins.code_actions.gomodifytags,

                    null_ls.builtins.formatting.golines,
                    null_ls.builtins.formatting.goimports,

                    -- null_ls.builtins.diagnostics.golangci_lint.with {
                    --     args = {
                    --         -- custom args because golangci_lint v2 isn't officially suported yet
                    --         -- see https://github.com/nvimtools/none-ls.nvim/issues/256
                    --         "run",
                    --         "--output.json.path=stdout",
                    --         "--show-stats=false",
                    --         "--allow-parallel-runners",
                    --         -- "--enable-only=exhaustruct",
                    --     },
                    -- },
                },
            })
        end,
    },
    -- completion
    {
        'saghen/blink.cmp',
        dependencies = {
            'rafamadriz/friendly-snippets',
            'Kaiser-Yang/blink-cmp-avante',
        },
        version = '1.*',
        opts = {
            fuzzy = {
                prebuilt_binaries = {
                    force_version = "v1.3.1"
                },
                implementation = "rust",
            },
            signature = {
                enabled = true,
                window = {
                    show_documentation = false,
                },
            },
            completion = {
                ghost_text = { enabled = false },
                documentation = {
                    auto_show = true,
                    auto_show_delay_ms = 500,
                }
            },
            snippets = { preset = 'luasnip' },
            sources = {
                default = { 'avante', 'snippets', 'lsp', 'path', 'buffer' },
                per_filetype = {
                    sql = { 'dadbod', 'buffer' },
                },
                providers = {
                    dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
                    avante = {
                        module = 'blink-cmp-avante',
                        name = 'Avante',
                        opts = {
                            -- options for blink-cmp-avante
                        }
                    }
                },           
            },
        },
    },
    -- typescript
    { "pmizio/typescript-tools.nvim" },
    -- UI for nvim-lsp progress
    { "j-hui/fidget.nvim", opts = {} },
    -- install and manage LSP servers
    { "mason-org/mason.nvim", opts = {} },
}
