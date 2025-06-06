local common = require("common")
local cmap = common.cmap
local nmap = common.nmap
local vmap = common.vmap
local imap = common.imap
local tmap = common.tmap
local leader = common.leader

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

function lsp_format_leader_command(pattern, augroup_name)
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup(augroup_name, {}),
      pattern = pattern,
      callback = function(ev)
        vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
        local opts = { buffer = ev.buf }
        vim.keymap.set('n', '<space>lf', function()
          vim.lsp.buf.format { async = true }
        end, opts)
      end,
    })
end

lsp_format_leader_command("*.rs", "RustUserLspConfig")
lsp_format_leader_command("*.go", "GoUserLspConfig")

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('CSharpUserLspConfig', {}),
  pattern = "*.cs",
  callback = function(ev)
    local opts = { buffer = ev.buf }
    local f = function()
        vim.api.nvim_command('write')
        local path = vim.api.nvim_buf_get_name(0)
        vim.fn.system { 'dotnet', 'csharpier', path }
        vim.api.nvim_command('edit')
    end
    vim.keymap.set('n', '<space>lf', f, opts)
  end,
})

-- for whatever reason `vim.lsp.buf.format` doesn't work
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('TypeScriptUserLspConfig', {}),
  pattern = "*.ts,*.tsx,*.js,*.jsx",
  callback = function(ev)
    local opts = { buffer = ev.buf }
    local f = function()
        local path = vim.api.nvim_buf_get_name(0)

        vim.api.nvim_command('write')
        vim.system({ 'prettier', '-w', path  }, { text = true }, function(obj)
            vim.schedule(function()
                vim.cmd("edit")
            end)
        end)
    end
    vim.keymap.set('n', '<space>lf', f, opts)
  end,
})
