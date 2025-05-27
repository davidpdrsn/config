local lspconfig = require('lspconfig')

lspconfig.rust_analyzer.setup{
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
}

vim.lsp.enable({
    'rust_analyzer',
    'csharp_ls',
    'ts_ls',
    'gopls',
    'eslint',
    'postgres_lsp',
})

-- enable completion
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client:supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    end
  end,
})

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

-- require('mini.completion').setup()

-- don't automatically select the first result in suggestions
vim.cmd("set completeopt+=noselect")

require("lsp_signature").setup({
    handler_opts = {
        border = "none"
    },
})

local luasnip = require('luasnip')
local lspkind = require('lspkind')
local cmp = require('cmp')

cmp.setup({
    preselect = cmp.PreselectMode.None,
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end,
    },
    mapping = {
        ['<C-y>'] = cmp.mapping.confirm({ select = false }),
        ['<C-n>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i','c'}),
        ['<C-p>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i','c'}),
    },
    sources = {
        { name = 'nvim_lsp' },
        { name = 'buffer' },
        { name = 'luasnip' },
    },
    formatting = {
        format = lspkind.cmp_format({
            mode = 'symbol', -- show only symbol annotations
            maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
            -- can also be a function to dynamically calculate max width such as 
            -- maxwidth = function() return math.floor(0.45 * vim.o.columns) end,
            ellipsis_char = '...', -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)
            show_labelDetails = true, -- show labelDetails in menu. Disabled by default
        })
    }
})
