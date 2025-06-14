local common = require("common")
local cmap = common.cmap
local nmap = common.nmap
local vmap = common.vmap
local imap = common.imap
local tmap = common.tmap
local leader = common.leader

--------------------------------------------
-- General setup
--------------------------------------------

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
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

-- don't automatically select the first result in suggestions
vim.cmd("set completeopt+=noselect")

require("lazy").setup({
    spec = {
        { import = "plugins" },
    },
    install = { colorscheme = { "catppuccin" } },
    checker = { enabled = true },
    change_detection = {
        enabled = true,
        notify = false,
    },
})

--------------------------------------------
-- Require components
--------------------------------------------

require("run_tests")
require("run_project")
require("run_project")

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
            print("Loaded " .. vim.fn.expand('%'))
        end, { buffer = true })
    end
})

imap("\\u", function()
    insert_guid()
end)

leader("cm", ":!chmod +x %<cr>")
leader("ev", ":tabedit $MYVIMRC<cr>:lcd ~/.config/nvim/<cr>")
leader("h", ":nohlsearch<cr>")
leader("k", function() vim.diagnostic.open_float({ source = true }) end)
leader("L", ":Lazy<cr>")

leader("m", ":call MergeTabs()<cr>")
leader("la", function() vim.lsp.buf.code_action() end)
leader("lr", function() vim.lsp.buf.rename() end)
leader("rn", ":call RenameFile()<cr>")

leader("x", ":set filetype=")

vim.cmd[[
    function! RenameFile()
        let old_name = expand('%')
        let new_name = input('New file name: ', expand('%'), 'file')
        if new_name != '' && new_name != old_name
            exec ':saveas ' . new_name
            exec ':silent !rm ' . old_name
            redraw!
        endif
    endfunction

    nmap <C-g><C-o> <Plug>window:quickfix:loop
]]

-- get path to current file in command mode with %%
cmap("%%", "<C-R>='\"'.expand('%:h').'/'.'\"'<cr>")

-- quickly insert semicolon or comma at end of line
leader(";", "maA;<esc>`a")
leader(",", "maA,<esc>`a")

leader("Q", ":qall!<cr>")

-- exit insert mode and save just by hitting ctrl-s
imap("<c-s>", "<esc>:w<cr>")
nmap("<c-s>", ":w<cr>")

-- intuitive movement over long lines
nmap("k", "gk")
nmap("j", "gj")

-- make Y work as expected
nmap("Y", "y$")

-- disable useless and annoying keys
nmap("Q", "<Nop>")

-- resize windows with the shift+arrow keys
nmap("<s-up>", "10<C-W>+")
nmap("<s-down>", "10<C-W>-")

-- Don't jump around when using * to search for word under cursor
-- Often I just want to see where else a word appears
vim.cmd[[
    nnoremap * :let @/ = '\<'.expand('<cword>').'\>'\|set hlsearch<C-M>
]]

-- Insert current file name with \f in insert mode
vim.cmd[[
    inoremap \f <C-R>=expand("%:t:r")<CR>
]]

-- from https://github.com/jferris/dotfiles/blob/master/vim/plugin/mergetabs.vim
vim.cmd[[
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
]]

-- show docs
nmap(
    'K',
    function()
        local filetype = vim.bo.filetype
        if vim.tbl_contains({ 'vim','help' }, filetype) then
            vim.cmd('h '.. vim.fn.expand('<cword>'))
        elseif vim.tbl_contains({ 'man' }, filetype) then
            vim.cmd('Man '.. vim.fn.expand('<cword>'))
        else
            vim.lsp.buf.hover()
        end
    end,
    { silent = true }
)

-- lsp
nmap('gd', function() vim.lsp.buf.definition() end)
nmap('gy', function() vim.lsp.buf.type_definition() end)
nmap('[g', function() vim.diagnostic.goto_prev() end)
nmap(']g', function() vim.diagnostic.goto_next() end)

vim.cmd[[
    " don't wanna retrain my fingers
    command! W w
    command! Q q
    command! Qall qall
]]

math.randomseed(os.time())
local random = math.random
function insert_guid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local le_guid = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)

    vim.cmd("execute \"norm i" .. le_guid .. "\"")
end

common.lsp_format_leader_command("*.rs", "RustUserLspConfig")
common.lsp_format_leader_command("*.go", "GoUserLspConfig")

common.custom_format_leader_command(
    "*.cs",
    function(path)
        return { 'dotnet', 'csharpier', path }
    end,
    "CSharpUserLspConfig"
)

common.custom_format_leader_command(
    "*.ts,*.tsx,*.js,*.jsx",
    function(path)
        return { 'format-prettier', path }
    end,
    "TypeScriptUserLspConfig"
)
