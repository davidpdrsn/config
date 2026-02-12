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

            vim.keymap.set("n", "<leader>b", builtin.buffers, { desc = "Find buffer" })
            vim.keymap.set(
                "n",
                "<leader>B",
                builtin.current_buffer_fuzzy_find,
                { desc = "Search in buffer" }
            )
            vim.keymap.set("n", "<leader>f", builtin.find_files, { desc = "Find file" })
            vim.keymap.set(
                "n",
                "<leader>F",
                telescope.extensions.recent_files.pick,
                { desc = "Find recent file" }
            )

            vim.keymap.set(
                "n",
                "<leader>lD",
                ":Telescope diagnostics severity=error<cr>",
                { desc = "Find LSP error" }
            )
            vim.keymap.set(
                "n",
                "<leader>lS",
                builtin.lsp_dynamic_workspace_symbols,
                { desc = "Find workspace symbols" }
            )
            vim.keymap.set(
                "n",
                "<leader>ld",
                ":Telescope diagnostics severity_limit=warn<cr>",
                { desc = "Find LSP warning" }
            )

            vim.keymap.set(
                "n",
                "<leader>ls",
                builtin.lsp_document_symbols,
                { desc = "Find buffer symbol" }
            )
            vim.keymap.set("n", "<leader>rg", builtin.live_grep, { desc = "Grep" })
            vim.keymap.set("n", "<leader>rG", builtin.grep_string, { desc = "Grep under cursor" })

            vim.keymap.set("n", "<leader>:", builtin.commands, { desc = "Find command" })

            vim.keymap.set("n", "gr", builtin.lsp_references, { desc = "Find references" })

            vim.keymap.set("n", "<leader>sn", function()
                builtin.find_files({ cwd = "~/config" })
            end, { desc = "Open file in config" })
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

            vim.keymap.set("n", "ga.", "<cmd>TextCaseOpenTelescope<CR>", { desc = "Change case" })
            vim.keymap.set("v", "ga.", "<cmd>TextCaseOpenTelescope<CR>", { desc = "Change case" })
        end,
    },
}
