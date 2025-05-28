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

require("tokyonight").setup({
  style = "night",
  dim_inactive = true,
  on_colors = function(colors)
    -- https://pinetools.com/lighten-color
    colors.bg = "#1e1f2c"
    colors.terminal_black = "NONE"
  end
})

require("catppuccin").setup({
    flavour = "mocha", -- auto, latte, frappe, macchiato, mocha
    dim_inactive = {
        enabled = true,
    },
    integrations = {
        leap = true,
    },
})

-- vim.cmd.colorscheme "tokyonight-night"
vim.cmd.colorscheme "catppuccin"

vim.cmd[[
    highlight SpecialComment guifg=#6c6c66
]]

--------------------------------------------
-- Requires
--------------------------------------------

require("plugins")
require("mappings")
require("lsp")
require("auto_cmd")
require("debugging")

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

require('textcase').setup()

require('telescope').load_extension('textcase')

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

require('smart-splits').setup()

require("keytrail").setup()

require('treewalker').setup({
    highlight = false,
    highlight_group = 'CursorLine',
    jumplist = true,
})
