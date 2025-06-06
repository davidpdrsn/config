local common = require("common")
local cmap = common.cmap
local nmap = common.nmap
local vmap = common.vmap
local imap = common.imap
local tmap = common.tmap
local leader = common.leader

return {
    -- fuzzy find all the things
    {
        'nvim-telescope/telescope.nvim',
        config = function()
            require("telescope").setup {
                defaults = require('telescope.themes').get_ivy {
                    file_ignore_patterns = { 
                        ".glb",
                        ".ogg",
                        ".png",
                        ".uid",
                    }
                },
                extensions = {
                    recent_files = {
                        only_cwd = true,
                        theme = 'ivy',
                    },
                    ["ui-select"] = {
                        require("telescope.themes").get_cursor()
                    }
                },
            }

            local telescope = require("telescope");
            local builtin = require("telescope/builtin");

            leader("b", builtin.buffers)
            leader("B", builtin.current_buffer_fuzzy_find)
            leader("f", builtin.find_files)
            leader("F", telescope.extensions.recent_files.pick)

            leader("lD", ":Telescope diagnostics severity=error<cr>")
            leader("lS", builtin.lsp_dynamic_workspace_symbols)
            leader("lo", builtin.current_buffer_fuzzy_find)
            leader("ld", ":Telescope diagnostics severity_limit=warn<cr>")

            leader("ls", builtin.lsp_document_symbols)
            leader("rg", builtin.live_grep)
            leader("rG", builtin.grep_string)

            leader(":", builtin.commands)

            nmap('gr', builtin.lsp_references)
        end
    },
    {
        'nvim-telescope/telescope-ui-select.nvim',
        config = function()
            require("telescope").load_extension("ui-select")
        end,
    },
    {
        "smartpde/telescope-recent-files",
        config = function()
            require("telescope").load_extension("recent_files")
        end,
    },
    {
        "johmsalas/text-case.nvim",
        config = function()
            require('textcase').setup()
            require('telescope').load_extension('textcase')

            nmap("ga.", "<cmd>TextCaseOpenTelescope<CR>")
            vmap("ga.", "<cmd>TextCaseOpenTelescope<CR>")
        end,
    },
}
