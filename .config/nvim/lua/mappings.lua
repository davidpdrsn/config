local telescope = require("telescope/builtin")
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

function leader(mapping, what_to_do, options)
    nmap("<leader>" .. mapping, what_to_do, options)
end

leader("b", function() telescope.buffers() end)
leader("B", function() telescope.current_buffer_fuzzy_find() end)
leader("T", function() telescope.builtin() end)
leader("cm", ":!chmod +x %<cr>")
leader("ev", ":tabedit $MYVIMRC<cr>:lcd ~/.config/nvim/<cr>")
leader("f", function() telescope.find_files() end)
leader("F", function() require('telescope').extensions.recent_files.pick() end)
leader("h", ":nohlsearch<cr>")
leader("k", function() vim.diagnostic.open_float({ source = true }) end)

leader("lD", ":Telescope diagnostics severity=error<cr>")
leader("lS", function() telescope.lsp_dynamic_workspace_symbols() end)
leader("lo", function() telescope.current_buffer_fuzzy_find() end)
leader("la", function() vim.lsp.buf.code_action() end)
leader("ld", ":Telescope diagnostics severity_limit=warn<cr>")
leader("lr", function() vim.lsp.buf.rename() end)
leader("ls", function() telescope.lsp_document_symbols() end)
leader("R", function() telescope.resume() end)
leader("rd", ":RustOpenExternalDocs<cr>")
leader("rg", function() telescope.live_grep() end)
leader("rG", function() telescope.grep_string() end)
leader("rm", ":RustExpandMacro<cr>")
leader("rn", ":call RenameFile()<cr>")
leader("ro", ":sp<cr>:RustOpenCargo<cr>")
leader("rp", ":RustParentModule<cr>")
leader("rr", ":RustRunnables<cr>")
leader(":", function() telescope.commands() end)

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

-- https://github.com/neovim/nvim-lspconfig
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    local opts = { buffer = ev.buf }
    vim.keymap.set('n', '<space>lf', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})

-- move lines
-- https://github.com/fedepujol/move.nvim
vmap('<S-j>', ':MoveBlock(1)<CR>')
vmap('<S-k>', ':MoveBlock(-1)<CR>')
