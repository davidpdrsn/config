local common = require("common")
local rust_root_dir = require("rust_root_dir").rust_root_dir

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

-- vim.g.godot_executable = "/Applications/Godot.app/Contents/MacOS/Godot"

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

  client.server_capabilities.semanticTokensProvider = nil
end

local lspconfig = require('lspconfig')

lspconfig.gdscript.setup({
    on_attach = on_attach,
})

lspconfig.csharp_ls.setup({
    on_attach = on_attach,
})

lspconfig.gopls.setup({
    on_attach = on_attach,
})

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics,
    {
        virtual_text = {
            {
                min = "Warning"
            }
        },
        underline = true,
        signs = true,
    }
)

vim.g.rustaceanvim = {
    server = {
        root_dir = rust_root_dir,
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
            },
        },
    }
}

local cmp = require('cmp')
local lspkind = require('lspkind')

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
        \   if getbufinfo('%')[0].name != '' && getbufinfo('%')[0].changed && stridx(getbufinfo('%')[0].name, "[dap-repl-") == -1
        \ |     write
        \ | endif

      au BufLeave * silent!
        \   if getbufinfo('%')[0].name != '' && getbufinfo('%')[0].changed && stridx(getbufinfo('%')[0].name, "[dap-repl-") == -1
        \ |     echom getbufinfo('%')[0].name
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

require('leap').add_default_mappings()

vim.cmd[[
    let g:hardtime_default_on = 1
]]

require("telescope").setup {
    defaults = {
        file_ignore_patterns = { 
            ".glb",
            ".ogg",
            ".png",
            ".uid",
        }
    },
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

require('treesj').setup({
    use_default_keymaps = false
})

require('bqf').setup({
    preview = {
        winblend = 0,
    }
})

--------------------------------------------
-- Debugging
--------------------------------------------

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

local dap = require("dap")

vim.fn.sign_define('DapBreakpoint', {text='🛑', texthl='', linehl='', numhl=''})

local dapui = require("dapui")
dapui.setup()

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
    -- {
    --     type = "godot",
    --     request = "launch",
    --     name = "Run from editor",
    -- },
    -- {
    --     type = "godot",
    --     request = "attach",
    --     name = "Attach to editor",
    -- }
}

-- Get colors working in the logs/repl window of nvim-dap-ui
-- https://github.com/mfussenegger/nvim-dap/issues/1114#issuecomment-2407914108
vim.g.baleia = require("baleia").setup({ })
vim.api.nvim_create_autocmd({ "FileType" }, {
   pattern = "dap-repl",
   callback = function()
      vim.g.baleia.automatically(vim.api.nvim_get_current_buf())
   end,
})

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
