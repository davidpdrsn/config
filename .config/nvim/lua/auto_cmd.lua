vim.cmd([[
    augroup resumeCursorPosition
        autocmd!

        autocmd BufReadPost *
            \ if line("'\"") > 0 && line("'\"") <= line("$") |
            \     exe "normal g`\"" |
            \ endif
    augroup END

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
        \   if getbufinfo('%')[0].name != '' && getbufinfo('%')[0].changed && stridx(getbufinfo('%')[0].name, "[dap-repl-") == -1
        \ |     write
        \ | endif

      au BufLeave * silent!
        \   if getbufinfo('%')[0].name != '' && getbufinfo('%')[0].changed && stridx(getbufinfo('%')[0].name, "[dap-repl-") == -1
        \ |     echom getbufinfo('%')[0].name
        \ |     write
        \ | endif
    augroup END
]])
