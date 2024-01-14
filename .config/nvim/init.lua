local common = require("common")

--------------------------------------------
-- General setup
--------------------------------------------

vim.g.mapleader = " "
vim.opt.scrolljump = 5
vim.opt.scrolloff = 3
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.ttimeoutlen = 1
vim.opt.updatetime = 100
vim.opt.mouse = "nv"
vim.opt.showmode = false
vim.opt.laststatus = 2
vim.opt.linebreak = true
vim.opt.number = true
vim.opt.numberwidth = 3
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.ignorecase = true
vim.opt.backup = true
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.backupdir = "/tmp"
vim.opt.dir = "/tmp"
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.softtabstop = 4
vim.opt.tabstop = 4
vim.opt.foldenable = false
vim.opt.spell = false

require("tokyonight").setup({
  style = "night",
  dim_inactive = true,
  on_colors = function(colors)
    -- https://pinetools.com/lighten-color
    colors.bg = "#1e1f2c"
    colors.terminal_black = "NONE"
  end
})

vim.cmd[[
    colorscheme tokyonight-night
    highlight SpecialComment guifg=#6c6c66
]]

--------------------------------------------
-- Requires
--------------------------------------------

require("plugins")
require("mappings")

--------------------------------------------
-- LSP
--------------------------------------------

function on_attach(client, bufnr)
  require("lsp_signature").on_attach({
      doc_lines = 0,
      handler_opts = {
          border = "none"
      },
  })

  -- require('illuminate').on_attach(client)

  client.server_capabilities.semanticTokensProvider = nil
end

require('lspconfig').tsserver.setup({
    on_attach = on_attach,
})

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics,
    {
        virtual_text = {
            severity_limit = "Warning",
        },
        underline = true,
        signs = true,
    }
)

require('rust-tools').setup({
    tools = {
        inlay_hints = {
            auto = false,
            only_current_line = false,
            show_parameter_hints = true,
            parameter_hints_prefix = "<- ",
            other_hints_prefix = "=> ",
            max_len_align = false,
            max_len_align_padding = 1,
            right_align = false,
            right_align_padding = 7,
            highlight = "Comment",
        },
    },
    server = {
        on_attach = on_attach,
        flags = {
            debounce_text_changes = 150,
        },
        capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities()),
        settings = {
            ["rust-analyzer"] = {
                inlayHints = {
                    chainingHints = false,
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
                        "/Users/david.pedersen/.rust-analyzer-target-dir",
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
            },
        },
    }
})

local cmp = require('cmp')

cmp.setup({
    snippet = {
        expand = function(args)
            require('luasnip').lsp_expand(args.body)
        end,
    },
    mapping = {
        ['<C-d>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(),
        ['<C-e>'] = cmp.mapping.close(),
        ['<C-y>'] = cmp.mapping.confirm({ select = true }),
        ['<C-n>'] = cmp.mapping(cmp.mapping.select_next_item(), {'i','c'}),
        ['<C-p>'] = cmp.mapping(cmp.mapping.select_prev_item(), {'i','c'}),
    },
    sources = {
        { name = 'buffer' },
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
    }
})

--------------------------------------------
-- Auto commands
--------------------------------------------

vim.cmd([[
    augroup resumeCursorPosition
        autocmd!

        autocmd BufReadPost *
            \ if line("'\"") > 0 && line("'\"") <= line("$") |
            \     exe "normal g`\"" |
            \ endif
    augroup END

    augroup miscGroup
        autocmd!

        " when in a git commit buffer go the beginning
        autocmd FileType gitcommit au! BufEnter COMMIT_EDITMSG call setpos('.', [0, 1, 1, 0])
    augroup END

    " https://stackoverflow.com/questions/14068751/how-to-hide-cursor-line-when-focus-in-on-other-window-in-vim
    augroup CursorLine
        au!
        au VimEnter * setlocal cursorline
        au WinEnter * setlocal cursorline
        au BufWinEnter * setlocal cursorline
        au WinLeave * setlocal nocursorline
    augroup END

    augroup autosave_buffer
      au!

      au FocusLost * silent!
        \   if getbufinfo('%')[0].name != '' && getbufinfo('%')[0].changed
        \ |     write
        \ | endif

      au BufLeave * silent!
        \   if getbufinfo('%')[0].name != '' && getbufinfo('%')[0].changed
        \ |     write
        \ | endif
    augroup END
]])

--------------------------------------------
-- Misc plugin setup
--------------------------------------------

require('nvim-autopairs').setup()
require('nvim-autopairs').remove_rule("'")

require('dressing').setup()
require("fidget").setup({
    fmt = {
        max_width = 50,
    },
})
require('numb').setup()
require("mason").setup()

require('nvim-treesitter.configs').setup({
    matchup = {
        enable = true,
    },
})

vim.g.highlightedyank_highlight_duration = 170

require('lualine').setup({
    sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = { "diagnostics", common.path_to_file },
        lualine_x = {},
        lualine_y = {},
        lualine_z = { common.filetype }
    },
    inactive_sections = {
        lualine_a = {},
        lualine_b = {
            "diagnostics",
        },
        lualine_c = { common.path_to_file, },
        lualine_x = {},
        lualine_y = {},
        lualine_z = {}
    },
})

require('leap').add_default_mappings()

vim.cmd[[
    let g:hardtime_default_on = 1
]]

require("telescope").setup {
  defaults = {},
  extensions = {
    recent_files = {
        only_cwd = true
    }
  }
}

require("telescope").load_extension("recent_files")

require('telescope').load_extension('textcase')

require('textcase').setup()

require("toggleterm").setup()

require("luasnip.loaders.from_snipmate").lazy_load({paths = "~/.config/nvim/snippets"})
require("luasnip.loaders.from_vscode").lazy_load()

require('gitsigns').setup()
