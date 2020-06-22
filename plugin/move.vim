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

function! s:MoveBlockDown(start, end, distance)
    if !&modifiable
        return
    endif

    let l:next_line = a:end + a:distance

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

function! s:MoveBlockUp(start, end, distance)
    if !&modifiable
        return
    endif

    let l:prev_line = a:start - a:distance - 1

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

function! s:MoveBlockLeft(distance) range
    let l:min_col = min([virtcol("'<"), virtcol("'>")])
    let l:distance = min([a:distance, l:min_col - 1])

    if !&modifiable || virtcol("$") == 1 || l:distance <= 0 || visualmode() ==# "V"
        normal! gv
        return
    endif

    if visualmode() ==# "v" && a:lastline - a:firstline > 0
        execute "silent normal! gv\<C-v>"
        echomsg "Switching to visual block mode for moving multiple lines with MoveBlockLeft"
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

function! s:MoveBlockRight(distance) range
    let l:max_col = max([virtcol("'<"), virtcol("'>")])

    let l:distance = a:distance
    if !g:move_past_end_of_line
        let l:shorter_line_len = min(map(getline(a:firstline, a:lastline), 'strwidth(v:val)'))
        let l:distance = min([l:shorter_line_len - l:max_col, l:distance])
    end

    if !&modifiable || virtcol("$") == 1 || l:distance <= 0
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

function! s:MoveLineUp(distance) range
    if !&modifiable || line('.') == 1
        return
    endif

    let l:relative_cursor_col = s:GetRelativeCursorVirtCol()

    if (line('.') - a:distance) < 0
        execute 'silent move 0'
        if (g:move_auto_indent == 1)
            normal! ==
        endif
        return
    endif

    execute 'silent m-' . (a:distance + 1)

    if (g:move_auto_indent == 1)
        normal! ==
    endif

    " restore cursor column position
    execute 'silent normal!' . max([1, (virtcol('.') + l:relative_cursor_col - 1)]) . '|'
endfunction

function! s:MoveLineDown(distance) range
    if !&modifiable || line('.') ==  line('$')
        return
    endif

    let l:relative_cursor_col = s:GetRelativeCursorVirtCol()

    if (line('.') + a:distance) > line('$')
        silent move $
        if (g:move_auto_indent == 1)
            normal! ==
        endif
        return
    endif

    execute 'silent m+' . a:distance
    if (g:move_auto_indent == 1)
        normal! ==
    endif

    " restore cursor column position
    execute 'silent normal!' . max([1, (virtcol('.') + l:relative_cursor_col - 1)]) . '|'
endfunction

" Using range here fucks the col() function (because col() always returns 1 in
" range functions), so use normal function and clear the range with <C-u> later
function! s:MoveCharLeft(distance)
    if !&modifiable || virtcol("$") == 1 || virtcol(".") == 1
        return
    endif

    call s:SaveDefaultRegister()

    if (virtcol('.') - a:distance <= 0)
        silent normal! x0P
    else
        let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'onemore']
        execute 'silent normal! x' . a:distance . 'hP'
        let &virtualedit = l:old_virtualedit
    endif

    call s:RestoreDefaultRegister()
endfunction

function! s:MoveCharRight(distance)
    if !&modifiable || virtcol("$") == 1
        return
    endif

    call s:SaveDefaultRegister()

    if !g:move_past_end_of_line && (virtcol('.') + a:distance >= virtcol('$') - 1)
        silent normal! x$p
    else
        let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'all']
        execute 'silent normal! x' . a:distance . 'lP'
        let &virtualedit = l:old_virtualedit
    endif

    call s:RestoreDefaultRegister()
endfunction

function! s:MoveBlockOneLineUp(count) range
    call s:MoveBlockUp(a:firstline, a:lastline, a:count)
endfunction

function! s:MoveBlockOneLineDown(count) range
    call s:MoveBlockDown(a:firstline, a:lastline, a:count)
endfunction

function! s:MoveBlockHalfPageUp(count) range
    let l:distance = a:count * (winheight('.') / 2)
    call s:MoveBlockUp(a:firstline, a:lastline, l:distance)
endfunction

function! s:MoveBlockHalfPageDown(count) range
    let l:distance = a:count * (winheight('.') / 2)
    call s:MoveBlockDown(a:firstline, a:lastline, l:distance)
endfunction

function! s:MoveLineHalfPageUp(count) range
    let l:distance = a:count * (winheight('.') / 2)
    call s:MoveLineUp(l:distance)
endfunction

function! s:MoveLineHalfPageDown(count) range
    let l:distance = a:count * (winheight('.') / 2)
    call s:MoveLineDown(l:distance)
endfunction

function! s:MoveKey(key)
    return '<' . g:move_key_modifier . '-' . a:key . '>'
endfunction


vnoremap <silent> <Plug>MoveBlockDown           :call <SID>MoveBlockOneLineDown(v:count1)<CR>
vnoremap <silent> <Plug>MoveBlockUp             :call <SID>MoveBlockOneLineUp(v:count1)<CR>
vnoremap <silent> <Plug>MoveBlockHalfPageDown   :call <SID>MoveBlockHalfPageDown(v:count1)<CR>
vnoremap <silent> <Plug>MoveBlockHalfPageUp     :call <SID>MoveBlockHalfPageUp(v:count1)<CR>
vnoremap <silent> <Plug>MoveBlockLeft           :call <SID>MoveBlockLeft(v:count1)<CR>
vnoremap <silent> <Plug>MoveBlockRight          :call <SID>MoveBlockRight(v:count1)<CR>

nnoremap <silent> <Plug>MoveLineDown            :call <SID>MoveLineDown(v:count1)<CR>
nnoremap <silent> <Plug>MoveLineUp              :call <SID>MoveLineUp(v:count1)<CR>
nnoremap <silent> <Plug>MoveLineHalfPageDown    :call <SID>MoveLineHalfPageDown(v:count1)<CR>
nnoremap <silent> <Plug>MoveLineHalfPageUp      :call <SID>MoveLineHalfPageUp(v:count1)<CR>
nnoremap <silent> <Plug>MoveCharLeft            :<C-u>call <SID>MoveCharLeft(v:count1)<CR>
nnoremap <silent> <Plug>MoveCharRight           :<C-u>call <SID>MoveCharRight(v:count1)<CR>


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
