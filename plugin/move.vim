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
    normal! =
    normal! gv
    normal! ^
endfunction

function! s:MoveBlockDown() range
    let next_line = a:lastline + 1

    if v:count > 0
        let next_line = next_line + v:count - 1
    endif

    if next_line > line('$')
        call s:ResetCursor()
        return
    endif

    execute a:firstline "," a:lastline "m " next_line
    call s:ResetCursor()
endfunction

function! s:MoveBlockUp() range
    let prev_line = a:firstline - 2

    if v:count > 0
        let prev_line = prev_line - v:count + 1
    endif

    if prev_line < 0
        call s:ResetCursor()
        return
    endif

    execute a:firstline "," a:lastline "m " prev_line
    call s:ResetCursor()
endfunction

function! s:MoveLineUp() range
    let distance = 2

    if v:count > 0
        let distance = distance + v:count - 1
    endif

    if (line('.') - distance) < 0
        execute 'm 0'
        normal! ==
        return
    endif

    execute 'm-' . distance
    normal! ==
endfunction

function! s:MoveLineDown() range
    let distance = 1

    if v:count > 0
        let distance = distance + v:count - 1
    endif

    echom distance

    if (line('.') + distance) > line('$')
        execute 'm $'
        normal! ==
        return
    endif

    execute 'm+' . distance
    normal! ==
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
