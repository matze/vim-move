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

function! s:ResetCursor()
    normal! gv=gv^
endfunction

function! s:SaveDefaultRegister()
   let s:default_register_value = @"
endfunction

function! s:RestoreDefaultRegister()
   let @" = s:default_register_value
endfunction

function! s:GetRelativeCursorVirtCol()
    let l:cursor_col = virtcol('.')
    silent normal! ^
    " cursor position relative line start taking into account of indentations
    return l:cursor_col - virtcol('.') + 1
endfunction

function! s:MoveBlockDown(start, end, count)
    if !&modifiable
        return
    endif

    let l:next_line = a:end + a:count

    if v:count > 0
        let l:next_line = l:next_line + v:count - 1
    endif

    if l:next_line > line('$')
        call s:ResetCursor()
        return
    endif

    execute 'silent' a:start ',' a:end 'move ' l:next_line
    if (g:move_auto_indent == 1)
        call s:ResetCursor()
    else
        normal! gv
    endif
endfunction

function! s:MoveBlockUp(start, end, count)
    if !&modifiable
        return
    endif

    let l:prev_line = a:start - a:count - 1

    if v:count > 0
        let l:prev_line = l:prev_line - v:count + 1
    endif

    if l:prev_line < 0
        call s:ResetCursor()
        return
    endif

    execute 'silent' a:start ',' a:end 'move ' l:prev_line
    if (g:move_auto_indent == 1)
        call s:ResetCursor()
    else
        normal! gv
    endif
endfunction

function! s:MoveBlockLeft() range
    let l:min_col = min([virtcol("'<"), virtcol("'>")])

    if !&modifiable || virtcol("$") == 1 || l:min_col == 1 || visualmode() ==# "V"
        normal! gv
        return
    endif

    if visualmode() ==# "v" && a:lastline - a:firstline > 0
        execute "silent normal! gv\<C-v>"
        echomsg "Switching to visual block mode for moving multiple lines with MoveBlockLeft"
        return
    endif

    let l:distance = min([l:min_col - 1, v:count ? v:count : 1])

    if l:distance < 1
        normal! gv
        return
    endif

    let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'onemore']
    call s:SaveDefaultRegister()

    " save previous cursor position
    silent normal! gv
    let l:row_pos = getcurpos()[1]
    let l:is_rhs = virtcol(".") == max([virtcol("'<"), virtcol("'>")])

    execute 'silent normal! gvd' . l:distance . "hP`[\<C-v>`]"

    " restore previous cursor position
    if getcurpos()[1] != l:row_pos
        silent normal! o
        if l:is_rhs
           silent normal! O
        endif
    elseif !l:is_rhs
        silent normal! O
    endif

    call s:RestoreDefaultRegister()
    let &virtualedit = l:old_virtualedit
endfunction

function! s:MoveBlockRight() range
    if !&modifiable || virtcol("$") == 1
        normal! gv
        return
    endif

    if visualmode() ==# "V"
        execute "silent normal! gv\<C-v>o0o$h"
        echomsg "Switching to visual block mode for moving whole line(s) with MoveBlockRight"
        return
    endif

    if visualmode() ==# "v" && a:lastline - a:firstline > 0
        execute "silent normal! gv\<C-v>"
        echomsg "Switching to visual block mode for moving multiple lines with MoveBlockRight"
        return
    endif

    let l:distance = v:count ? v:count : 1

    let l:lens = map(getline(a:firstline, a:lastline), 'strwidth(v:val)')
    let l:shorter_line_len = min(l:lens)
    let l:max_col = max([virtcol("'<"), virtcol("'>")])

    if !g:move_past_end_of_line && (l:max_col + l:distance >= l:shorter_line_len)
        let l:distance = l:shorter_line_len - l:max_col

        if l:distance <= 0
            silent normal! gv
            return
        endif
    endif

    let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'all']
    call s:SaveDefaultRegister()

    " save previous cursor position
    silent normal! gv
    let l:row_pos = getcurpos()[1]
    let l:is_rhs = virtcol(".") == l:max_col

    execute 'silent normal! gvd' . l:distance . "l"
    " P behaves inconsistently in virtualedit 'all' mode; sometimes the cursor
    " moves one right after pasting, other times it doesn't. This makes it
    " difficult to rely on `[ to determine the start of the shifted selection.
    let l:new_start_pos = virtcol(".")
    execute 'silent normal! P' . l:new_start_pos . "|\<C-v>`]"

    " restore previous cursor position
    if getcurpos()[1] != l:row_pos
        silent normal! o
        if l:is_rhs
           silent normal! O
        endif
    elseif !l:is_rhs
        silent normal! O
    endif

    call s:RestoreDefaultRegister()
    let &virtualedit = l:old_virtualedit
endfunction

function! s:MoveLineUp(count) range
    if !&modifiable || line('.') == 1
        return
    endif

    let l:relative_cursor_col = s:GetRelativeCursorVirtCol()
    let l:distance = a:count + 1

    if v:count > 0
        let l:distance = l:distance + v:count - 1
    endif

    if (line('.') - l:distance) < 0
        execute 'silent move 0'
        if (g:move_auto_indent == 1)
            normal! ==
        endif
        return
    endif

    execute 'silent m-' . l:distance

    if (g:move_auto_indent == 1)
        normal! ==
    endif

    " restore cursor column position
    execute 'silent normal!' . max([1, (virtcol('.') + l:relative_cursor_col - 1)]) . '|'
endfunction

function! s:MoveLineDown(count) range
    if !&modifiable || line('.') ==  line('$')
        return
    endif

    let l:relative_cursor_col = s:GetRelativeCursorVirtCol()
    let l:distance = a:count

    if v:count > 0
        let l:distance = l:distance + v:count - 1
    endif

    if (line('.') + l:distance) > line('$')
        silent move $
        if (g:move_auto_indent == 1)
            normal! ==
        endif
        return
    endif

    execute 'silent m+' . l:distance
    if (g:move_auto_indent == 1)
        normal! ==
    endif

    " restore cursor column position
    execute 'silent normal!' . max([1, (virtcol('.') + l:relative_cursor_col - 1)]) . '|'
endfunction

" Using range here fucks the col() function (because col() always returns 1 in
" range functions), so use normal function and clear the range with <C-u> later
function! s:MoveCharLeft()
    if !&modifiable || virtcol("$") == 1 || virtcol(".") == 1
        return
    endif

    let l:distance = v:count ? v:count : 1

    call s:SaveDefaultRegister()

    if (virtcol('.') - l:distance <= 0)
        silent normal! x0P
    else
        let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'onemore']
        execute 'silent normal! x' . l:distance . 'hP'
        let &virtualedit = l:old_virtualedit
    endif

    call s:RestoreDefaultRegister()
endfunction

function! s:MoveCharRight()
    if !&modifiable || virtcol("$") == 1
        return
    endif

    let l:distance = v:count ? v:count : 1
    call s:SaveDefaultRegister()

    if !g:move_past_end_of_line && (virtcol('.') + l:distance >= virtcol('$') - 1)
        silent normal! x$p
    else
        let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'all']
        execute 'silent normal! x' . l:distance . 'lP'
        let &virtualedit = l:old_virtualedit
    endif

    call s:RestoreDefaultRegister()
endfunction

function! s:MoveBlockOneLineUp() range
    call s:MoveBlockUp(a:firstline, a:lastline, 1)
endfunction

function! s:MoveBlockOneLineDown() range
    call s:MoveBlockDown(a:firstline, a:lastline, 1)
endfunction

function! s:MoveBlockHalfPageUp() range
    let l:distance = winheight('.') / 2
    call s:MoveBlockUp(a:firstline, a:lastline, l:distance)
endfunction

function! s:MoveBlockHalfPageDown() range
    let l:distance = winheight('.') / 2
    call s:MoveBlockDown(a:firstline, a:lastline, l:distance)
endfunction

function! s:MoveLineHalfPageUp() range
    let l:distance = winheight('.') / 2
    call s:MoveLineUp(l:distance)
endfunction

function! s:MoveLineHalfPageDown() range
    let l:distance = winheight('.') / 2
    call s:MoveLineDown(l:distance)
endfunction

function! s:MoveKey(key)
    return '<' . g:move_key_modifier . '-' . a:key . '>'
endfunction


vnoremap <silent> <Plug>MoveBlockDown           :call <SID>MoveBlockOneLineDown()<CR>
vnoremap <silent> <Plug>MoveBlockUp             :call <SID>MoveBlockOneLineUp()<CR>
vnoremap <silent> <Plug>MoveBlockHalfPageDown   :call <SID>MoveBlockHalfPageDown()<CR>
vnoremap <silent> <Plug>MoveBlockHalfPageUp     :call <SID>MoveBlockHalfPageUp()<CR>
vnoremap <silent> <Plug>MoveBlockLeft           :call <SID>MoveBlockLeft()<CR>
vnoremap <silent> <Plug>MoveBlockRight          :call <SID>MoveBlockRight()<CR>

nnoremap <silent> <Plug>MoveLineDown            :call <SID>MoveLineDown(1)<CR>
nnoremap <silent> <Plug>MoveLineUp              :call <SID>MoveLineUp(1)<CR>
nnoremap <silent> <Plug>MoveLineHalfPageDown    :call <SID>MoveLineHalfPageDown()<CR>
nnoremap <silent> <Plug>MoveLineHalfPageUp      :call <SID>MoveLineHalfPageUp()<CR>
nnoremap <silent> <Plug>MoveCharLeft            :<C-u>call <SID>MoveCharLeft()<CR>
nnoremap <silent> <Plug>MoveCharRight           :<C-u>call <SID>MoveCharRight()<CR>


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
