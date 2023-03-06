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
  dim_inactive = true,
  on_colors = function(colors)
    -- https://pinetools.com/lighten-color
    colors.bg = "#1e1f2c"
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

  require('illuminate').on_attach(client)
end

require('lspconfig').tsserver.setup({
    on_attach = on_attach,
})

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics,
    {
        virtual_text = true,
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
                    command = "clippy",
                    enable = true,
                    extraArgs = { "--target-dir", "/Users/david.pedersen/.rust-analyzer-target-dir" },
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
            vim.fn["UltiSnips#Anon"](args.body)
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
        { name = 'ultisnips' },
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

        " save files when focus is lost
        autocmd BufLeave * silent! update
    augroup END

    " https://stackoverflow.com/questions/14068751/how-to-hide-cursor-line-when-focus-in-on-other-window-in-vim
    augroup CursorLine
        au!
        au VimEnter * setlocal cursorline
        au WinEnter * setlocal cursorline
        au BufWinEnter * setlocal cursorline
        au WinLeave * setlocal nocursorline
    augroup END
]])

--------------------------------------------
-- Misc plugin setup
--------------------------------------------

require('nvim-autopairs').setup()
require('nvim-autopairs').remove_rule("'")

require('dressing').setup()
require("fidget").setup()
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

require("FTerm").setup({
    border = "rounded",
})

require('leap').add_default_mappings()

vim.cmd[[
    let g:hardtime_default_on = 1
]]
