" =============================================================================
" File: plugin/move.vim
" Description: Move lines and selections up and even down.
" Author: Matthias Vogelgesang <github.com/matze>
" Version: 0.1
" =============================================================================


if exists('loaded_move') || &cp
    finish
endif

let loaded_move = 1

if !exists('g:move_map_keys')
    let g:move_map_keys = 1
endif

function! s:ResetCursor()
    normal! gv
    normal! ^
endfunction

function! s:MoveBlockDown() range
    let next_line = a:lastline + 1

    if next_line > line('$')
        call s:ResetCursor()
        return
    endif

    execute a:firstline "," a:lastline "m " next_line
    call s:ResetCursor()
endfunction

function! s:MoveBlockUp() range
    let prev_line = a:firstline - 2

    if prev_line < 0
        call s:ResetCursor()
        return
    endif

    execute a:firstline "," a:lastline "m " prev_line
    call s:ResetCursor()
endfunction

function! s:MoveLineUp()
    if line('.') == line('0')
        return
    endif
    execute 'm-2'
endfunction

function! s:MoveLineDown()
    if line('.') == line('0')
        return
    endif
    execute 'm+1'
endfunction

vnoremap <silent> <Plug>MoveBlockDown :call <SID>MoveBlockDown()<CR>
vnoremap <silent> <Plug>MoveBlockUp   :call <SID>MoveBlockUp()<CR>
nnoremap <silent> <Plug>MoveLineDown  :call <SID>MoveLineDown()<CR>
nnoremap <silent> <Plug>MoveLineUp    :call <SID>MoveLineUp()<CR>

if g:move_map_keys
    vmap <C-j> <Plug>MoveBlockDown
    vmap <C-k> <Plug>MoveBlockUp
    nmap <A-j> <Plug>MoveLineDown
    nmap <A-k> <Plug>MoveLineDown
endif
