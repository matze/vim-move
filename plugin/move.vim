" =============================================================================
" File: plugin/move.vim
" Description: Move lines and selections up and even down.
" Author: Matthias Vogelgesang <github.com/matze>
" =============================================================================

if exists('g:loaded_move') || &compatible
    finish
endif

let g:loaded_move = 1

if !exists('g:move_map_keys')
    let g:move_map_keys = 1
endif

if !exists('g:move_key_modifier')
    let g:move_key_modifier = 'A'
endif

if !exists('g:move_auto_indent')
    let g:move_auto_indent = 1
endif

if !exists('g:move_past_end_of_line')
    let g:move_past_end_of_line = 1
endif

"
" In normal mode, move the current line vertically.
" Moves down if (distance > 0) and up if (distance < 0).
"
function! s:MoveLineVertically(distance)
    if !&modifiable
        return
    endif

    " Remember the current cursor position. When we move or reindent a line
    " Vim will move the cursor to the first non-blank character.
    let l:old_cursor_col = virtcol('.')
    normal! ^
    let l:old_indent     = virtcol('.')

    if a:distance <= 0
        let l:after = max([1,         line('.') + a:distance]) - 1
    else
        let l:after = min([line('$'), line('.') + a:distance])
    endif
    execute 'move' l:after

    if g:move_auto_indent
        normal! ==
    endif

    " Restore the cursor column, taking indentation changes into account.
    let l:new_indent = virtcol('.')
    let l:new_cursor_col = max([1, l:old_cursor_col - l:old_indent + l:new_indent])
    execute 'normal!'  (l:new_cursor_col . '|')
endfunction

"
" In visual mode, move the selected lines vertically.
" Moves down if (distance > 0) and up if (distance < 0).
"
function s:MoveBlockVertically(distance)
    if !&modifiable
        return
    endif

    let l:first = line("'<")
    let l:last  = line("'>")

    if a:distance <= 0
        let l:after = max([1,         l:first + a:distance]) - 1
    else
        let l:after = min([line('$'), l:last  + a:distance])
    endif
    execute l:first ',' l:last 'move ' l:after

    if g:move_auto_indent
        normal! gv=
    endif

    normal! gv
endfunction

"
" In normal mode, move the character under the cursor horizontally
" Moves right (distance > 0) and left if (distance < 0).
"
function! s:MoveCharHorizontally(distance)
    if !&modifiable
        return
    endif

    let l:curr = virtcol('.')
    let l:before = l:curr + a:distance
    if !g:move_past_end_of_line
        let l:before = max([1, min([l:before, virtcol('$')-1])])
    endif

    if l:curr == l:before
        " Don't add an empty change to the undo stack.
        return
    endif

    let l:old_default_register = @"
    let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'all']

    normal! x
    execute 'normal!' . (l:before.'|')
    normal! P

    let &virtualedit = l:old_virtualedit
    let @" = l:old_default_register

endfunction

"
" In visual mode, move the selected block to the left
" Moves right (distance > 0) and left if (distance < 0).
" Switches to visual-block mode first if another visual mode is selected.
"
function! s:MoveBlockHorizontally(distance)
    if !&modifiable
        return
    endif

    if visualmode() ==# 'V'
        echomsg 'vim-move: Cannot move horizontally in linewise visual mode'
        return
    endif

    normal! gv

    if visualmode() ==# 'v'
        echomsg 'vim-move: Switching to visual block mode'
        execute "normal! \<C-v>"
    endif

    let l:cols = [virtcol("'<"), virtcol("'>")]
    let l:first = min(l:cols)
    let l:last  = max(l:cols)
    let l:width = l:last - l:first + 1

    let l:before = max([1, l:first + a:distance])
    if a:distance > 0 && !g:move_past_end_of_line
        let l:shortest = min(map(getline("'<", "'>"), 'strwidth(v:val)'))
        if l:last < l:shortest
            let l:before = min([l:before, l:shortest - width + 1])
        else
            let l:before = l:first
        endif
    endif

    if l:first == l:before
        " Don't add an empty change to the undo stack.
        return
    endif

    let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'all']
    let l:old_default_register = @"

    normal! d
    execute 'normal!' . (l:before.'|')
    normal! P

    let @" = l:old_default_register
    let &virtualedit = l:old_virtualedit

    " Reselect the pasted text.
    " For some reason, `[ doesn't always point where it should -- sometimes it
    " is off by one. Maybe it is because of the virtualedit=all? The
    " workaround we found is to recompute the destination column by hand.
    execute 'normal!' . (l:before.'|') . "\<C-v>`]"

endfunction


function! s:HalfPageSize()
    return winheight('.') / 2
endfunction

function! s:MoveKey(key)
    return '<' . g:move_key_modifier . '-' . a:key . '>'
endfunction

" Note: An older version of this program used callbacks with the "range"
" attribute to support being called with a selection range as a parameter.
" However, that had some problems: we would get E16 errors if the user tried
" to perform an out-of bounds move and the computations that used col() would
" also return the wrong results. Because of this, we have switched everything
" to using <C-u>.

vnoremap <silent> <Plug>MoveBlockDown           :<C-u> call <SID>MoveBlockVertically( v:count1)<CR>
vnoremap <silent> <Plug>MoveBlockUp             :<C-u> call <SID>MoveBlockVertically(-v:count1)<CR>
vnoremap <silent> <Plug>MoveBlockHalfPageDown   :<C-u> call <SID>MoveBlockVertically( v:count1 * <SID>HalfPageSize())<CR>
vnoremap <silent> <Plug>MoveBlockHalfPageUp     :<C-u> call <SID>MoveBlockVertically(-v:count1 * <SID>HalfPageSize())<CR>
vnoremap <silent> <Plug>MoveBlockRight          :<C-u> call <SID>MoveBlockHorizontally( v:count1)<CR>
vnoremap <silent> <Plug>MoveBlockLeft           :<C-u> call <SID>MoveBlockHorizontally(-v:count1)<CR>

nnoremap <silent> <Plug>MoveLineDown            :<C-u> call <SID>MoveLineVertically( v:count1)<CR>
nnoremap <silent> <Plug>MoveLineUp              :<C-u> call <SID>MoveLineVertically(-v:count1)<CR>
nnoremap <silent> <Plug>MoveLineHalfPageDown    :<C-u> call <SID>MoveLineVertically( v:count1 * <SID>HalfPageSize())<CR>
nnoremap <silent> <Plug>MoveLineHalfPageUp      :<C-u> call <SID>MoveLineVertically(-v:count1 * <SID>HalfPageSize())<CR>
nnoremap <silent> <Plug>MoveCharRight           :<C-u> call <SID>MoveCharHorizontally( v:count1)<CR>
nnoremap <silent> <Plug>MoveCharLeft            :<C-u> call <SID>MoveCharHorizontally(-v:count1)<CR>


if g:move_map_keys
    execute 'vmap' s:MoveKey('j') '<Plug>MoveBlockDown'
    execute 'vmap' s:MoveKey('k') '<Plug>MoveBlockUp'
    execute 'vmap' s:MoveKey('h') '<Plug>MoveBlockLeft'
    execute 'vmap' s:MoveKey('l') '<Plug>MoveBlockRight'

    execute 'nmap' s:MoveKey('j') '<Plug>MoveLineDown'
    execute 'nmap' s:MoveKey('k') '<Plug>MoveLineUp'
    execute 'nmap' s:MoveKey('h') '<Plug>MoveCharLeft'
    execute 'nmap' s:MoveKey('l') '<Plug>MoveCharRight'
endif
