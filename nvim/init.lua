local common = require("common")

--------------------------------------------
-- General setup
--------------------------------------------

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        lazyrepo,
        lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
            { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
            { out, "WarningMsg" },
            { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
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
vim.opt.smartcase = true
vim.opt.softtabstop = 4
vim.opt.tabstop = 4
vim.opt.foldenable = false
vim.opt.spell = false
vim.o.confirm = true

-- don't automatically select the first result in suggestions
vim.cmd("set completeopt+=noselect")

require("lazy").setup({
    spec = {
        { import = "plugins" },
    },
    install = { colorscheme = { "catppuccin" } },
    checker = {
        enabled = false,
        notify = true,
        frequency = 3600,
    },
    change_detection = {
        enabled = true,
        notify = false,
    },
})

vim.cmd.colorscheme("catppuccin")

vim.notify = require("notify")

--------------------------------------------
-- Require components
--------------------------------------------

require("run_tests")
require("run_project")
require("test_file")

--------------------------------------------
-- Auto commands
--------------------------------------------

vim.cmd([[
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

    augroup CursorCol
        au!
        au FileType yaml setlocal cursorcolumn
    augroup END

    augroup autosave_buffer
      au!

      au FocusLost * silent!
        \   if getbufinfo('%')[0].name != '' && getbufinfo('%')[0].changed && stridx(getbufinfo('%')[0].name, "[dap-repl-") == -1 && stridx(getbufinfo('%')[0].name, "oil://") == -1
        \ |     write
        \ | endif

      au BufLeave * silent!
        \   if getbufinfo('%')[0].name != '' && getbufinfo('%')[0].changed && stridx(getbufinfo('%')[0].name, "[dap-repl-") == -1 && stridx(getbufinfo('%')[0].name, "oil://") == -1
        \ |     echom getbufinfo('%')[0].name
        \ |     write
        \ | endif
    augroup END
]])

vim.api.nvim_create_autocmd("FileType", {
    pattern = "nix",
    callback = function()
        vim.opt_local.shiftwidth = 2
        vim.opt_local.tabstop = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.expandtab = true
        vim.opt_local.smartindent = false
        vim.opt_local.cindent = false
    end,
})

--------------------------------------------
-- Mappings
--------------------------------------------

vim.api.nvim_create_autocmd("FileType", {
    pattern = "lua",
    callback = function()
        vim.keymap.set("n", "<leader>o", function()
            vim.cmd("source %")
            print("Loaded " .. vim.fn.expand("%"))
        end, { buffer = true, desc = "Source current file" })
    end,
})

math.randomseed(os.time())
local random = math.random

vim.keymap.set("i", "\\u", function()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    local le_guid = string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
        return string.format("%x", v)
    end)
    vim.cmd("execute \"norm i" .. le_guid .. "\"")
end, { desc = "Insert GUID" })

vim.keymap.set("n", "<leader>cm", ":!chmod +x %<cr>", { desc = "Make file executable" })
vim.keymap.set("n", "<leader>h", ":nohlsearch<cr>", { desc = "Remove search highlight" })
-- vim.keymap.set("n", "<leader>K", function()
--     vim.diagnostic.open_float({ source = true })
-- end, { desc = "Open diagnostic for curret line" })
vim.keymap.set("n", "<leader>L", ":Lazy<cr>", { desc = "Open Lazy" })
vim.keymap.set("n", "<leader>lu", ":Lazy update<cr>", { desc = "Update plugins" })

vim.keymap.set("n", "<leader>m", ":call MergeTabs()<cr>", { desc = "Merge tab" })
vim.keymap.set("n", "<leader>rn", ":call RenameFile()<cr>", { desc = "Rename file" })

vim.keymap.set("n", "<leader>x", ":set filetype=", { desc = "Set filetype" })

vim.cmd([[
    function! RenameFile()
        let old_name = expand('%')
        let new_name = input('New file name: ', expand('%'), 'file')
        if new_name != '' && new_name != old_name
            exec ':saveas ' . new_name
            exec ':silent !rm ' . old_name
            redraw!
        endif
    endfunction
]])

vim.keymap.set("n", "<C-g><C-o>", "<Plug>window:quickfix:loop", { desc = "Close quickfix" })

-- quickly insert semicolon or comma at end of line
vim.keymap.set("n", "<leader>;", "maA;<esc>`a", { desc = "Insert ; at end of line" })
vim.keymap.set("n", "<leader>,", "maA,<esc>`a", { desc = "Insert , at end of line" })

vim.keymap.set("n", "<leader>Q", ":qall!<cr>", { desc = "Force quit" })

-- copy current file path to system clipboard
vim.keymap.set("n", "<leader>cp", function()
    local path = vim.fn.expand("%:.")
    vim.fn.setreg("+", path)
    vim.notify(path, "info", { title = "Copied to clipboard" })
end, { desc = "Copy path to current file" })

-- exit insert mode and save just by hitting ctrl-s
vim.keymap.set("i", "<c-s>", "<esc>:w<cr>", { desc = "Save and leave insert mode" })
vim.keymap.set("n", "<c-s>", ":w<cr>", { desc = "Save" })

-- intuitive movement over long lines
vim.keymap.set("n", "k", "gk", { desc = "Move one line up" })
vim.keymap.set("n", "j", "gj", { desc = "Move one line down" })

-- make Y work as expected
vim.keymap.set("n", "Y", "y$", { desc = "Yank until end of line" })

-- disable useless and annoying keys
vim.keymap.set("n", "Q", "<Nop>", { desc = "NOP" })

-- resize windows with the shift+arrow keys
vim.keymap.set("n", "<s-up>", "10<C-W>+", { desc = "Increase window size" })
vim.keymap.set("n", "<s-down>", "10<C-W>-", { desc = "Decrease window size" })

-- Don't jump around when using * to search for word under cursor
-- Often I just want to see where else a word appears
vim.cmd([[
    nnoremap * :let @/ = '\<'.expand('<cword>').'\>'\|set hlsearch<C-M>
]])

-- Insert current file name with \f in insert mode
vim.cmd([[
    inoremap \f <C-R>=expand("%:t:r")<CR>
]])

-- from https://github.com/jferris/dotfiles/blob/master/vim/plugin/mergetabs.vim
vim.cmd([[
    function! MergeTabs()
     if tabpagenr() == 1
        return
      endif
      let bufferName = bufname("%")
      if tabpagenr("$") == tabpagenr()
        close!
      else
        close!
        tabprev
      endif
      split
      execute "buffer " . bufferName
    endfunction
]])

-- show docs
vim.keymap.set("n", "K", function()
    local filetype = vim.bo.filetype
    if vim.tbl_contains({ "vim", "help" }, filetype) then
        vim.cmd("h " .. vim.fn.expand("<cword>"))
    elseif vim.tbl_contains({ "man" }, filetype) then
        vim.cmd("Man " .. vim.fn.expand("<cword>"))
    else
        vim.lsp.buf.hover()
    end
end, { silent = true, desc = "Show docs" })

-- lsp
vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "LSP code actions" })

vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "LSP rename" })

vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Goto definition" })

vim.keymap.set("n", "gy", vim.lsp.buf.type_definition, { desc = "Goto type definition" })

vim.keymap.set("n", "[g", function()
    vim.diagnostic.jump({ count = -1 })
end, { desc = "Prev diagnostic" })

vim.keymap.set("n", "]g", function()
    vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })

vim.keymap.set(
    "n",
    "<leader>q",
    vim.diagnostic.setloclist,
    { desc = "Open diagnostic [Q]uickfix list" }
)

vim.cmd([[
    " don't wanna retrain my fingers
    command! W w
    command! Q q
    command! Qall qall
]])

common.lsp_format_leader_command("rust")
common.lsp_format_leader_command("go")

vim.api.nvim_create_autocmd("BufWritePre", {
    pattern = "*.go",
    callback = function(ev)
        vim.lsp.buf.format({ async = false })
    end,
})

common.custom_format_leader_command("cs", function(path)
    return { "csharpier", "format", path }
end)

common.custom_format_leader_command("typescriptreact,typescript", function(path)
    return { "format-prettier", path }
end)

common.custom_format_leader_command("nix", function(path)
    return { "alejandra", path }
end)

common.custom_format_leader_command("lua", function(path)
    return { "stylua", "--config-path", os.getenv("HOME") .. "/.stylua.toml", path }
end)

vim.keymap.set("n", "<leader>v", function()
    common.tmux_run(vim.api.nvim_get_current_line())
end, { desc = "Send current line to tmux" })

vim.keymap.set("v", "<leader>v", function()
    -- leave visual mode so the marks update
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

    vim.schedule(function()
        local vstart = vim.fn.getpos("'<")
        local vend = vim.fn.getpos("'>")
        local line_start = vstart[2]
        local line_end = vend[2]

        local lines = vim.fn.getline(line_start, line_end)

        for _, line in pairs(lines) do
            common.tmux_run(line)
        end
    end)
end, { desc = "Send current selection to tmux" })

vim.keymap.set("n", "<leader><leader>", function()
    local original_win_id = vim.api.nvim_get_current_win()
    vim.cmd("botright 20new")
    local term_buf = vim.api.nvim_get_current_buf()
    vim.fn.jobstart(vim.fn.expand("~/.cargo/bin/t"), {
        term = true,
        on_exit = function(_, status)
            if status == 0 then
                vim.api.nvim_set_current_win(original_win_id)
                vim.api.nvim_buf_delete(term_buf, { force = false })
            end
        end,
    })
    vim.cmd("startinsert")
end, { desc = "Run CLI" })

vim.keymap.set("v", "<leader>cp", function()
    vim.api.nvim_set_hl(0, "FlashyCopy", { bg = "#C3B1E1", fg = "#000000" })

    -- leave visual mode so the marks update
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)

    vim.schedule(function()
        local vstart = vim.fn.getpos("'<")
        local vend = vim.fn.getpos("'>")
        local line_start = vstart[2]
        local line_end = vend[2]

        local bufnr = vim.api.nvim_get_current_buf()
        local ns_id = vim.api.nvim_create_namespace("copy_highlight")

        local received_data = {}

        local job_id = vim.fn.jobstart({ "remove-indentation" }, {
            on_stdout = function(job_id, data, event)
                for _, line in ipairs(data) do
                    table.insert(received_data, line)
                end
            end,

            on_exit = function(job_id, exit_code, event)
                vim.fn.setreg("+", table.concat(received_data, "\n"))

                for i = line_start, line_end do
                    vim.api.nvim_buf_add_highlight(bufnr, ns_id, "FlashyCopy", i - 1, 0, -1)
                end
                vim.defer_fn(function()
                    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
                end, 200)
            end,
        })

        local lines = vim.fn.getline(line_start, line_end)
        for _, line in pairs(lines) do
            vim.fn.jobsend(job_id, line .. "\n")
        end
        vim.fn.chanclose(job_id, "stdin")
    end)
end, { desc = "Copy selection (unindented)" })
