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
" Move and possibly reindent the given lines.
" Goes down if (distance > 0) and up if (distance < 0).
" Places the cursor at last moved line.
"
function s:MoveVertically(first, last, distance)
    if !&modifiable
        return
    endif

    " To avoid 'Invalid range' errors we must ensure that the destination
    " line is valid and that we don't try to move a range into itself.
    if a:distance <= 0
        let l:after = max([1,         a:first + a:distance]) - 1
    else
        let l:after = min([line('$'), a:last  + a:distance])
    endif
    execute a:first ',' a:last 'move ' l:after

    " After a :move the '[ and '] marks point to first and last moved line
    " and the cursor is placed at the last line.
    if g:move_auto_indent
        normal! g'[=g']
    endif

endfunction

"
" In normal mode, move the current line vertically.
" The cursor stays pointing at the same character as before.
"
function s:MoveLineVertically(distance)

    let l:old_col    = virtcol('.')
    normal! ^
    let l:old_indent = virtcol('.')

    call s:MoveVertically(line('.'), line('.'), a:distance)

    normal! ^
    let l:new_indent = virtcol('.')
    let l:new_col    = max([1, l:old_col - l:old_indent + l:new_indent])
    execute 'normal!'  (l:new_col . '|')
endfunction

"
" In visual mode, move the selected lines vertically.
" Maintains the current selection, albeit not exactly if auto_indent is on.
"
function s:MoveBlockVertically(distance)

    call s:MoveVertically(line("'<"), line("'>"), a:distance)
    normal! gv

endfunction


"
" If in normal mode, moves the character under the cursor.
" If in blockwise visual mode, moves the selected rectangular area.
" Goes right if (distance > 0) and left if (distance < 0).
" Returns whether an edit was made.
"
function s:MoveHorizontally(corner1, corner2, distance)
    if !&modifiable
        return 0
    endif

    let l:cols = [virtcol(a:corner1), virtcol(a:corner2)]
    let l:first = min(l:cols)
    let l:last  = max(l:cols)
    let l:width = l:last - l:first + 1

    let l:before = max([1, l:first + a:distance])
    if a:distance > 0 && !g:move_past_end_of_line
        let l:shortest = min(map(getline(a:corner1, a:corner2), 'strwidth(v:val)'))
        if l:last < l:shortest
            let l:before = min([l:before, l:shortest - l:width + 1])
        else
            let l:before = l:first
        endif
    endif

    if l:first == l:before
        " Don't add an empty change to the undo stack
        return 0
    endif

    let l:old_default_register = @"
    normal! x

    let l:old_virtualedit = &virtualedit
    if l:before >= virtcol('$')
        let &virtualedit = 'all'
    else
        " Because of a Vim <= 8.2 bug, we must disable virtualedit in this case.
        " See https://github.com/vim/vim/pull/6430
        let &virtualedit = ''
    endif

    execute 'normal!' . (l:before.'|')
    normal! P

    let &virtualedit = l:old_virtualedit
    let @" = l:old_default_register

    return 1
endfunction

"
" In normal mode, move the character under the cursor horizontally
"
function s:MoveCharHorizontally(distance)

    call s:MoveHorizontally('.', '.', a:distance)

endfunction

"
" If in blockwise visual mode, move the selected rectangular area.
" If in characterwise visual mode do the same, after switching to blockwise.
" If in linewise visual mode, do nothing.
"
function s:MoveBlockHorizontally(distance)

    normal! gv

    if visualmode() ==# 'V'
        echoerr 'vim-move: Cannot move horizontally in linewise visual mode'
        return
    endif

    if visualmode() ==# 'v'
        execute "normal! \<C-v>"
    endif

    if s:MoveHorizontally("'<", "'>", a:distance)
        execute "normal! g`[\<C-v>g`]"
    endif

endfunction


function s:HalfPageSize()
    return winheight('.') / 2
endfunction

function s:MoveKey(key)
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
