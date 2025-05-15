local M = {}

local telescope = require("telescope/builtin")
local dap = require("dap")
local dap_go = require('dap-go')
local dapui = require("dapui")
local Terminal = require('toggleterm.terminal').Terminal

function make_map_fn(mode)
    return function(mapping, what_to_do, options)
        options = options or {}
        if options.noremap == nil then
            options.noremap = true
        end

        vim.keymap.set(mode, mapping, what_to_do, options)
    end
end

local cmap = make_map_fn("c")
local nmap = make_map_fn("n")
local vmap = make_map_fn("v")
local imap = make_map_fn("i")
local tmap = make_map_fn("t")

imap("\\u", function()
    insert_guid()
end)

nmap("ga.", '<cmd>TextCaseOpenTelescope<CR>', { desc = "Telescope" })
vmap("ga.", '<cmd>TextCaseOpenTelescope<CR>', { desc = "Telescope" })

function leader(mapping, what_to_do, options)
    nmap("<leader>" .. mapping, what_to_do, options)
end

leader("b", function() telescope.buffers() end)
leader("B", function() telescope.current_buffer_fuzzy_find() end)
leader("cm", ":!chmod +x %<cr>")
leader("ev", ":tabedit $MYVIMRC<cr>:lcd ~/.config/nvim/<cr>")
leader("f", function() telescope.find_files() end)
leader("F", function() require('telescope').extensions.recent_files.pick() end)
leader("h", ":nohlsearch<cr>")
leader("k", function() vim.diagnostic.open_float({ source = true }) end)

local go_test_command

leader("t", function()
    vim.api.nvim_command('write')
    vim.fn.system { 'touch', '/Users/davidpdrsn/.config/cli/command' }
end)
leader("T", function()
    vim.api.nvim_command('write')

    local buf = vim.api.nvim_buf_get_name(0)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    print(buf, line)
    vim.fn.system {
        '/Users/davidpdrsn/.cargo/bin/t',
        'watch test',
        buf,
        line,
    }
end)

leader("dt", dap_go.debug_test)
leader("dT", dap_go.debug_last_test)
leader("dd", dap.toggle_breakpoint)
leader("dc", dap.continue)
leader("dr", dap.restart)
leader("ds", function()
    dap.terminate()
    require("dapui").close()
end)
leader("D", function()
    dapui.close()
    dapui.open()
end)
leader("<up>", dap.step_out)
leader("<down>", dap.step_into)
leader("<left>", dap.step_back)
leader("<right>", dap.step_over)

leader("m", ":call MergeTabs()<cr>")
leader("gu", ":UndotreeToggle<cr>")
leader("lD", ":Telescope diagnostics severity=error<cr>")
leader("lS", function() telescope.lsp_dynamic_workspace_symbols() end)
leader("lo", function() telescope.current_buffer_fuzzy_find() end)
leader("la", function() vim.lsp.buf.code_action() end)
leader("ld", ":Telescope diagnostics severity_limit=warn<cr>")
leader("lr", function() vim.lsp.buf.rename() end)
leader("ls", function() telescope.lsp_document_symbols() end)
leader("rd", ":RustLsp externalDocs<cr>")
leader("rg", function() telescope.live_grep() end)
leader("rG", function() telescope.grep_string() end)
leader("rm", ":RustLsp expandMacro<cr>")
leader("rn", ":call RenameFile()<cr>")
leader("ro", ":sp<cr>:RustLsp openCargo<cr>")
leader("rp", ":RustLsp parentModule<cr>")
leader("rr", ":RustLsp runnables<cr>")
leader(":", function() telescope.commands() end)
leader("w", ":WinShift<cr>")
leader("W", ":WinShift swap<cr>")
leader("j", function() require('treesj').toggle() end)

leader("s", "<Plug>(leap-cross-window)")
leader("x", ":set filetype=")
leader("u", ":UndotreeToggle<cr>")

leader("ps", ":so<cr>:PackerSync<cr>")

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
cmap("%%", "<C-R>=expand('%:h').'/'<cr>")

-- quickly insert semicolon or comma at end of line
leader(";", "maA;<esc>`a")
leader(",", "maA,<esc>`a")

-- exit insert mode and save just by hitting ctrl-s
imap("<c-s>", "<esc>:w<cr>")
nmap("<c-s>", ":w<cr>")

-- snippets
imap('<c-k>', function() require("luasnip").expand() end, { silent = true })
imap('<c-j>', function() require("luasnip").jump(1) end, { silent = true })

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

-- term
local term = Terminal:new({
    direction = "float",
    float_opts = {
        border = 'single',
    }
})
nmap('<c-t>', function()
    term:toggle()
end)

-- lsp
nmap('gd', function() vim.lsp.buf.definition() end)
nmap('gy', function() vim.lsp.buf.type_definition() end)
nmap('gr', function() telescope.lsp_references() end)
nmap('[g', function() vim.diagnostic.goto_prev() end)
nmap(']g', function() vim.diagnostic.goto_next() end)

vim.cmd[[
    " don't wanna retrain my fingers
    command! W w
    command! Q q
    command! Qall qall

    command! Replace lua require('spectre').open()

    autocmd TermEnter term://*toggleterm#*
          \ tnoremap <silent><c-t> <Cmd>exe v:count1 . "ToggleTerm"<CR>
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

vim.cmd[[
    command! Uuid lua insert_guid()
]]

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

return M
