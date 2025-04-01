vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'
    -- Vim syntax for TOML
    use 'cespare/vim-toml'
    -- repeat things with "g."
    use 'christoomey/Vim-g-dot'
    -- Vim mapping for sorting a range of text
    use 'christoomey/vim-sort-motion'
    -- copy to system clipboard
    use 'christoomey/vim-system-copy'
    -- seamless navigation between vim and tmux
    use 'christoomey/vim-tmux-navigator'
    -- colorscheme
    use 'folke/tokyonight.nvim'
    -- jsonnet syntax
    use 'google/vim-jsonnet'
    -- status line
    use 'nvim-lualine/lualine.nvim'
    -- "ae" text object
    use 'kana/vim-textobj-entire'
    -- define custom text objects, dependency of other plugins
    use 'kana/vim-textobj-user'
    -- highlight yanked text
    use 'machakann/vim-highlightedyank'
    -- dependency of other plugins
    use 'nvim-lua/plenary.nvim'
    -- fuzzy find all the things
    use 'nvim-telescope/telescope.nvim'
    -- mkdir for full path
    use 'pbrisbin/vim-mkdir'
    -- yaml syntax
    use 'stephpy/vim-yaml'
    -- comment stuff
    use 'tpope/vim-commentary'
    -- helpers for UNIX
    use 'tpope/vim-eunuch'
    -- enable repeating supported plugin maps with "."
    use 'tpope/vim-repeat'
    -- use CTRL-A/CTRL-X to increment dates, times, and more
    use 'tpope/vim-speeddating'
    -- Delete/change/add surrounding things with ease
    use 'tpope/vim-surround'
    -- better netrw
    use 'tpope/vim-vinegar'
    -- protobuf syntax
    use 'uarun/vim-protobuf'
    -- autopairs
    use 'windwp/nvim-autopairs'
    -- markdown syntax
    use 'plasticboy/vim-markdown'
    -- improve the default vim.ui interfaces
    use 'stevearc/dressing.nvim'
    -- syntax parser
    use {
        'nvim-treesitter/nvim-treesitter',
        run = function() require('nvim-treesitter.install').update({ with_sync = true }) end,
    }
    -- jump to matching thing
    use 'andymass/vim-matchup'
    -- multiple cursors
    use 'mg979/vim-visual-multi'
    -- highlight other occurances of words
    use 'RRethy/vim-illuminate'
    -- snippets
    use({
        "L3MON4D3/LuaSnip",
        tag = "v2.*",
    })
    -- nvim-cmp source for snippets
    use 'saadparwaiz1/cmp_luasnip'
    -- nvim-cmp source for buffer words
    use 'hrsh7th/cmp-buffer'
    -- nvim-cmp source for lsp
    use 'hrsh7th/cmp-nvim-lsp'
    -- nvim-cmp source for paths
    use 'hrsh7th/cmp-path'
    -- completion
    use 'hrsh7th/nvim-cmp'
    -- UI for nvim-lsp progress
    use 'j-hui/fidget.nvim'
    -- easy lsp config
    use 'neovim/nvim-lspconfig'
    -- popup api from vim in Neovim
    use 'nvim-lua/popup.nvim'
    -- lsp signature hint as you type
    use 'ray-x/lsp_signature.nvim'
    -- rust things
    use 'mrcjkb/rustaceanvim'
    -- peek lines when jumping
    use 'nacro90/numb.nvim'
    -- move around
    use 'ggandor/leap.nvim'
    -- icons
    use 'kyazdani42/nvim-web-devicons'
    -- floating terminal
    use 'akinsho/toggleterm.nvim'
    -- undo history tree
    use 'mbbill/undotree'
    -- install and manage LSP servers
    use "williamboman/mason.nvim"
    -- theme
    use "AlexvZyl/nordic.nvim"
    -- theme
    use "rebelot/kanagawa.nvim"
    -- recent files in telescope
    use "smartpde/telescope-recent-files"
    -- change case
    use "johmsalas/text-case.nvim"
    -- git wrapper
    use "tpope/vim-fugitive"
    -- godot
    use "habamax/vim-godot"
    -- arrange windows
    use "sindrets/winshift.nvim"
    -- split/join things on multiple lines
    use "Wansmer/treesj"
    -- better quickfix window
    use "kevinhwang91/nvim-bqf"
    -- toggle quickfix
    use "drmingdrmer/vim-toggle-quickfix"
    -- icons in lsp suggestions window
    use "onsails/lspkind.nvim"
    -- debugging
    use { "rcarriga/nvim-dap-ui", requires = {"mfussenegger/nvim-dap", "nvim-neotest/nvim-nio"} }
    use "stevearc/overseer.nvim"
    use "m00qek/baleia.nvim"
    -- typescript
    use "pmizio/typescript-tools.nvim"
end)
