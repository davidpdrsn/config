local common = require("common")
local run_tests = require("run_tests")

return {
    -- colorscheme
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        config = function()
            require("catppuccin").setup({
                flavour = "mocha",
                -- flavour = "latte",
                dim_inactive = {
                    enabled = true,
                },
                integrations = {
                    leap = true,
                },
                no_italic = true,
            })

            vim.cmd([[
                highlight SpecialComment guifg=#6c6c66
            ]])
        end,
    },
    -- repeat things with "g."
    { "christoomey/Vim-g-dot" },
    -- copy to system clipboard
    {
        "christoomey/vim-system-copy",
        config = function()
            -- otherwise it doesn't work with nushell
            vim.g["system_copy#copy_command"] = "pbcopy"
            vim.g["system_copy#paste_command"] = "pbpaste"
        end,
    },
    -- seamless navigation between vim and multiplexers
    {
        "mrjones2014/smart-splits.nvim",
        config = function()
            require("smart-splits").setup()
            local smart_splits = require("smart-splits")
            vim.keymap.set("n", "<c-h>", smart_splits.move_cursor_left, { desc = "Move left" })
            vim.keymap.set("n", "<c-j>", smart_splits.move_cursor_down, { desc = "Move down" })
            vim.keymap.set("n", "<c-k>", smart_splits.move_cursor_up, { desc = "Move up" })
            vim.keymap.set("n", "<c-l>", smart_splits.move_cursor_right, { desc = "Move right" })
        end,
    },
    -- Delete/change/add surrounding things with ease
    { "tpope/vim-surround" },
    -- file explorer
    {
        "stevearc/oil.nvim",
        lazy = false,
        config = function()
            require("oil").setup({
                keymaps = {
                    ["<C-h>"] = false,
                    ["<C-j>"] = false,
                    ["<C-k>"] = false,
                    ["<C-s>"] = false,
                    ["<C-l>"] = false,
                },
                view_options = {
                    show_hidden = true,
                },
                columns = {},
                lsp_file_methods = {
                    enabled = false,
                },
            })

            vim.api.nvim_create_autocmd("FileType", {
                pattern = "oil",
                callback = function()
                    local smart_splits = require("smart-splits")
                    vim.keymap.set("n", "<C-h>", smart_splits.move_cursor_left, { buffer = true, desc = "Move left" })
                    vim.keymap.set("n", "<C-j>", smart_splits.move_cursor_down, { buffer = true, desc = "Move down" })
                    vim.keymap.set("n", "<C-k>", smart_splits.move_cursor_up, { buffer = true, desc = "Move up" })
                    vim.keymap.set("n", "<C-l>", smart_splits.move_cursor_right, { buffer = true, desc = "Move right" })
                end,
            })

            vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "File browser" })
        end,
    },
    -- status line
    {
        "nvim-lualine/lualine.nvim",
        opts = {
            sections = {
                lualine_a = { "mode" },
                lualine_b = { "branch" },
                lualine_c = { "diagnostics", common.path_to_file },
                lualine_x = {},
                lualine_y = { run_tests.test_for_status },
                lualine_z = { common.filetype },
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {
                    "diagnostics",
                },
                lualine_c = { common.path_to_file },
                lualine_x = {},
                lualine_y = {},
                lualine_z = {},
            },
        },
    },
    -- autopairs
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = true,
    },
    -- improve the default vim.ui interfaces
    { "stevearc/dressing.nvim", opt = {} },
    -- peek lines when jumping
    {
        "nacro90/numb.nvim",
        config = function()
            require("numb").setup()
        end,
    },
    -- "ae" text object
    {
        "kana/vim-textobj-entire",
        dependencies = {
            "kana/vim-textobj-user",
        },
    },
    -- highlight yanked text
    {
        "machakann/vim-highlightedyank",
        config = function()
            vim.g.highlightedyank_highlight_duration = 170
        end,
    },
    -- dependency of other plugins
    { "nvim-lua/plenary.nvim" },
    -- mkdir for full path
    { "pbrisbin/vim-mkdir" },
    -- comment stuff
    { "tpope/vim-commentary" },
    -- helpers for UNIX
    { "tpope/vim-eunuch" },
    -- enable repeating supported plugin maps with "."
    { "tpope/vim-repeat" },
    -- move around
    {
        url = "https://codeberg.org/andyg/leap.nvim",
        config = function()
            local leap = require("leap")

            -- Set up default keymaps manually
            vim.keymap.set({'n', 'x', 'o'}, 's', '<Plug>(leap-forward)')
            vim.keymap.set({'n', 'x', 'o'}, 'S', '<Plug>(leap-backward)')
            vim.keymap.set({'n', 'x', 'o'}, 'gs', '<Plug>(leap-from-window)')

            vim.keymap.set("n", "<leader>s", "<Plug>(leap-cross-window)", { desc = "Big leap" })
        end,
    },
    -- icons
    { "kyazdani42/nvim-web-devicons" },
    -- popup api from vim in Neovim
    { "nvim-lua/popup.nvim" },
    -- undo history tree
    {
        "mbbill/undotree",
        config = function()
            vim.keymap.set("n", "<leader>u", ":UndotreeToggle<cr>", { desc = "Toggle undo tree" })
        end,
    },
    -- godot
    { "habamax/vim-godot" },
    -- jump to matching thing
    { "andymass/vim-matchup" },
    -- multiple cursors
    { "mg979/vim-visual-multi" },
    -- split/join things on multiple lines
    {
        "Wansmer/treesj",
        config = function()
            require("treesj").setup({
                use_default_keymaps = false,
            })
            vim.keymap.set(
                "n",
                "<leader>j",
                require("treesj").toggle,
                { desc = "Join/split lines" }
            )
        end,
    },
    -- better quickfix window
    {
        "kevinhwang91/nvim-bqf",
        opts = {
            preview = {
                winblend = 0,
            },
        },
    },
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "master",
        lazy = false,
        build = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup({
                matchup = {
                    enable = true,
                },
            })
        end,
    },
    -- arrange windows
    {
        "sindrets/winshift.nvim",
        config = function()
            vim.keymap.set("n", "<leader>w", ":WinShift<cr>", { desc = "Arrange windows" })
            vim.keymap.set("n", "<leader>W", ":WinShift swap<cr>", { desc = "Swap windows" })
        end,
    },
    -- snippets
    {
        "L3MON4D3/LuaSnip",
        -- follow latest release.
        version = "v2.*",
        build = "make install_jsregexp",
        config = function()
            require("luasnip.loaders.from_snipmate").lazy_load({ paths = "~/.config/nvim/snippets" })
            require("luasnip.loaders.from_vscode").lazy_load()

            -- Not sure what these do
            -- vim.keymap.set("i", "<c-k>", require("luasnip").expand, { silent = true })
            -- vim.keymap.set("i", "<c-j>", function()
            --     require("luasnip").jump(1)
            -- end, { silent = true })
        end,
    },
    -- toggle quickfix
    { "drmingdrmer/vim-toggle-quickfix" },
    -- restore cursor position
    {
        "ethanholz/nvim-lastplace",
        opts = {},
    },
    {
        "kristijanhusak/vim-dadbod-ui",
        dependencies = {
            { "tpope/vim-dadbod", lazy = true },
            {
                "kristijanhusak/vim-dadbod-completion",
                -- ft = { "sql", "mysql", "plsql" },
                lazy = true,
            },
        },
        cmd = {
            "DBUI",
            "DBUIToggle",
            "DBUIAddConnection",
            "DBUIFindBuffer",
        },
        init = function()
            -- Your DBUI configuration
            vim.g.db_ui_use_nerd_fonts = 1
        end,
    },
    -- notifications
    { "rcarriga/nvim-notify" },
}
