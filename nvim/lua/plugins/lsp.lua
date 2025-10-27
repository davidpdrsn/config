local common = require("common")

return {
    -- install and manage LSP servers
    { "mason-org/mason.nvim", opts = {} },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {},
        },
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
        },
    },
    -- highlight other occurances of words
    { "RRethy/vim-illuminate" },
    -- easy lsp config
    {
        "neovim/nvim-lspconfig",
        config = function()
            local lspconfig = require("lspconfig")

            vim.lsp.config("rust_analyzer", {
                settings = {
                    ["rust-analyzer"] = {
                        inlayHints = {
                            chainingHints = true,
                        },
                        cargo = {
                            features = "all",
                            autoreload = true,
                            buildScripts = {
                                enable = true,
                            },
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
                            disabled = { "macro-error" },
                        },
                        procMacro = {
                            enable = true,
                            attributes = {
                                enable = true,
                            },
                        },
                        rustcSource = "discover",
                    },
                },
            })

            vim.lsp.enable({
                "csharp_ls",
                "eslint",
                "gopls",
                "ts_ls",
                "rust_analyzer",
                "nil_ls",
                "clangd",
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
                    null_ls.builtins.formatting.golines,
                    null_ls.builtins.formatting.goimports,
                    -- null_ls.builtins.code_actions.impl,
                    -- null_ls.builtins.code_actions.gomodifytags,
                    -- null_ls.builtins.diagnostics.golangci_lint,
                },
            })
        end,
    },
    -- completion
    {
        "saghen/blink.cmp",
        dependencies = {
            "rafamadriz/friendly-snippets",
            "Kaiser-Yang/blink-cmp-avante",
        },
        version = "1.*",
        opts = {
            fuzzy = {
                implementation = "prefer_rust_with_warning",
                frecency = {
                    enabled = true,
                },
                use_proximity = true,
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
                },
            },
            snippets = { preset = "luasnip" },
            sources = {
                default = { "avante", "snippets", "lsp", "path", "buffer" },
                per_filetype = {
                    -- sql = { "dadbod", "buffer" },
                },
                providers = {
                    dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
                    avante = {
                        module = "blink-cmp-avante",
                        name = "Avante",
                        opts = {
                            -- options for blink-cmp-avante
                        },
                    },
                },
            },
        },
    },
    -- typescript
    { "pmizio/typescript-tools.nvim" },
    -- UI for nvim-lsp progress
    {
        "j-hui/fidget.nvim",
        opts = {
            notification = {
                window = {
                    max_width = 30,
                    max_height = 5,
                },
            },
        },
    },
    -- prettier diagnostic messages
    {
        "rachartier/tiny-inline-diagnostic.nvim",
        event = "VeryLazy",
        priority = 1000,
        config = function()
            require("tiny-inline-diagnostic").setup()
            vim.diagnostic.config({ virtual_text = false })
        end,
    },
}
