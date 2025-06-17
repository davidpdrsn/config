local common = require("common")

return {
    -- fuzzy find all the things
    {
        "nvim-telescope/telescope.nvim",
        config = function()
            require("telescope").setup({
                defaults = require("telescope.themes").get_ivy({
                    file_ignore_patterns = {
                        ".glb",
                        ".ogg",
                        ".png",
                        ".uid",
                    },
                }),
                extensions = {
                    recent_files = {
                        only_cwd = true,
                        theme = "ivy",
                    },
                    ["ui-select"] = {
                        require("telescope.themes").get_cursor(),
                    },
                },
            })

            local telescope = require("telescope")
            local builtin = require("telescope/builtin")

            vim.keymap.set("n", "<leader>b", builtin.buffers)
            vim.keymap.set("n", "<leader>B", builtin.current_buffer_fuzzy_find)
            vim.keymap.set("n", "<leader>f", builtin.find_files)
            vim.keymap.set("n", "<leader>F", telescope.extensions.recent_files.pick)

            vim.keymap.set("n", "<leader>lD", ":Telescope diagnostics severity=error<cr>")
            vim.keymap.set("n", "<leader>lS", builtin.lsp_dynamic_workspace_symbols)
            vim.keymap.set("n", "<leader>lo", builtin.current_buffer_fuzzy_find)
            vim.keymap.set("n", "<leader>ld", ":Telescope diagnostics severity_limit=warn<cr>")

            vim.keymap.set("n", "<leader>ls", builtin.lsp_document_symbols)
            vim.keymap.set("n", "<leader>rg", builtin.live_grep)
            vim.keymap.set("n", "<leader>rG", builtin.grep_string)

            vim.keymap.set("n", "<leader>:", builtin.commands)

            vim.keymap.set("n", "gr", builtin.lsp_references)
        end,
    },
    {
        "nvim-telescope/telescope-ui-select.nvim",
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
            require("textcase").setup()
            require("telescope").load_extension("textcase")

            vim.keymap.set("n", "ga.", "<cmd>TextCaseOpenTelescope<CR>")
            vim.keymap.set("v", "ga.", "<cmd>TextCaseOpenTelescope<CR>")
            vim.keymap.set("n", "gaP", function()
                require("textcase").lsp_rename("to_pascal_case")
            end)
        end,
    },
}
