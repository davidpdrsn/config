vim.cmd [[packadd packer.nvim]]

return require('packer').startup(function(use)
    -- Packer can manage itself
    use 'wbthomason/packer.nvim'
    -- repeat things with "g."
    use 'christoomey/Vim-g-dot'
    -- copy to system clipboard
    use 'christoomey/vim-system-copy'
    -- seamless navigation between vim and multiplexers
    use 'mrjones2014/smart-splits.nvim'
    -- colorscheme
    use 'folke/tokyonight.nvim'
    use { "catppuccin/nvim", as = "catppuccin" }
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
    use 'nvim-telescope/telescope-ui-select.nvim'
    -- mkdir for full path
    use 'pbrisbin/vim-mkdir'
    -- comment stuff
    use 'tpope/vim-commentary'
    -- helpers for UNIX
    use 'tpope/vim-eunuch'
    -- enable repeating supported plugin maps with "."
    use 'tpope/vim-repeat'
    -- Delete/change/add surrounding things with ease
    use 'tpope/vim-surround'
    -- autopairs
    use 'windwp/nvim-autopairs'
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
    use {
        "L3MON4D3/LuaSnip",
        tag = "v2.*",
    }
    -- UI for nvim-lsp progress
    use 'j-hui/fidget.nvim'
    -- easy lsp config
    use 'neovim/nvim-lspconfig'
    -- popup api from vim in Neovim
    use 'nvim-lua/popup.nvim'
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
    use "leoluz/nvim-dap-go"
    -- typescript
    use "pmizio/typescript-tools.nvim"
    -- more lsp code actions
    use "nvimtools/none-ls.nvim"
    -- send things to tmux
    use "jgdavey/tslime.vim"
    -- completion
    use {
        'saghen/blink.cmp',
        tag = "v1.3.1",
    }
    -- database ui
    -- (:DBUI)
    use 'tpope/vim-dadbod'
    use 'kristijanhusak/vim-dadbod-ui'
    use 'kristijanhusak/vim-dadbod-completion'
    -- file explorer
    use 'stevearc/oil.nvim'
    -- restore cursor position
    use 'ethanholz/nvim-lastplace'
    -- ai
    use 'MunifTanjim/nui.nvim'
    use 'MeanderingProgrammer/render-markdown.nvim'
    use 'Kaiser-Yang/blink-cmp-avante'
    use {
        'yetone/avante.nvim',
        branch = 'main',
        run = 'make',
    }
end)
