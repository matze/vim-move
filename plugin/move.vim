" =============================================================================
" File: plugin/move.vim
" Description: Move lines and selections up, down, left and even right to the
"              infinity.
" Author: Matthias Vogelgesang <github.com/matze>
" =============================================================================

if exists('g:loaded_move') || &compatible
    finish
endif
let g:loaded_move = 1

" =====[ Configuration Variables ]================
function! s:SetDefaultValue(var, val)
    if !exists(a:var)
        execute 'let' a:var '=' string(a:val)
    endif
endfunction

call s:SetDefaultValue('g:move_map_keys', 1)
call s:SetDefaultValue('g:move_key_modifier', 'A')
call s:SetDefaultValue('g:move_auto_indent', 1)
call s:SetDefaultValue('g:move_map_keys', 1)
call s:SetDefaultValue('g:move_past_end_of_line', 1)

if type(g:move_map_keys) == type({})
    call s:SetDefaultValue('g:move_map_keys.vertical', {})
    call s:SetDefaultValue('g:move_map_keys.vertical.normal', 1)
    call s:SetDefaultValue('g:move_map_keys.vertical.visual', 1)
    call s:SetDefaultValue('g:move_map_keys.horizontal', {})
    call s:SetDefaultValue('g:move_map_keys.horizontal.normal', 1)
    call s:SetDefaultValue('g:move_map_keys.horizontal.visual', 1)
endif

" =====[ Script local variables ]=================
let s:command_blockwise_selection = "\<C-v>"
" After deleting and pasting "gv" would select the old position but the
" following command selects the position of the pasted text
let s:command_select_after_P = '`[' . s:command_blockwise_selection . '`]'

" =====[ Utility functions ]======================
function! s:ResetCursor()
    normal! gv=gv^
endfunction

function! s:AssertBlockwiseVisual(mode)
    if a:mode ==# 'v'
        execute 'normal!' s:command_blockwise_selection
    endif
endfunction

function! s:HalfWin()
    return winheight('.') / 2
endfunction

function! s:MoveKey(key)
    return '<' . g:move_key_modifier . '-' . a:key . '>'
endfunction

" =====[ Functionality ]==========================
function! s:MoveBlockDown(start, end, num)
    let l:next_line = a:end + a:num + max([0, v:count - 1])
    let l:next_line = min([line('$'), l:next_line])

    execute 'silent' a:start ',' a:end 'move ' l:next_line
    if (g:move_auto_indent == 1)
        call s:ResetCursor()
    else
        normal! gv
    endif
endfunction

function! s:MoveBlockUp(start, end, num)
    let l:prev_line = a:start - a:num - 1 - max([0, v:count - 1])
    let l:prev_line = max([0, l:prev_line])

    execute 'silent' a:start ',' a:end 'move ' l:prev_line
    if (g:move_auto_indent == 1)
        call s:ResetCursor()
    else
        normal! gv
    endif
endfunction

function! s:MoveBlockLeft() range
    call s:AssertBlockwiseVisual(visualmode())

    let l:distance = v:count ? v:count : 1
    let l:min_col  = min([col("'<"), col("'>")])

    " Having 'virtualenv' set to 'onemore' fixes problem of one more movement
    " that needed when moving block from end of line to the left
    let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'onemore']

    let l:move_command = 'silent normal! gvd'
    if l:min_col - l:distance <= 1
        let l:move_command .= '0P'
    else
        let l:move_command .= l:distance . 'hP'
    endif
    execute l:move_command . s:command_select_after_P

    let &virtualedit = l:old_virtualedit
endfunction

function! s:MoveBlockRight() range
    call s:AssertBlockwiseVisual(visualmode())

    let l:distance = v:count ? v:count : 1
    let l:lens = map(getline(a:firstline, a:lastline), 'len(v:val)')
    let l:shorter_line_len = min(l:lens)

    let l:are_same_cols = (col("'<") == col("'>"))
    let l:max_col       = max([col("'<"), col("'>")])

    if !g:move_past_end_of_line && (l:max_col + l:distance >= l:shorter_line_len)
        let l:distance = l:shorter_line_len - l:max_col

        if l:distance == 0
            silent normal! gv
            return
        endif
    endif

    let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'all']

    execute 'silent normal! gvd' . l:distance . 'lP' . s:command_select_after_P

    " When 'virtualedit' is set to all the selection loses one column at the
    " left at reselection. The next line fixes it
    if !l:are_same_cols && (l:max_col + l:distance < l:lens[0])
        normal! oho
    endif

    let &virtualedit = l:old_virtualedit
endfunction

function! s:MoveLineUp(count)
    let l:distance = a:count + 1 + max([0, v:count - 1])

    let l:command = 'silent move '
    if (line('.') - l:distance) < 0
        let l:command .= '0'
    else
        let l:command .= '-' . l:distance
    endif
    execute l:command

    if (g:move_auto_indent == 1)
        normal! ==
    endif
endfunction

function! s:MoveLineDown(count)
    let l:distance = a:count + max([0, v:count - 1])

    let l:command = 'silent move '
    if (line('.') + l:distance) > line('$')
        let l:command .= '$'
    else
        let l:command .= '+' . l:distance
    endif
    execute l:command

    if (g:move_auto_indent == 1)
        normal! ==
    endif
endfunction

function! s:MoveCharLeft()
    let l:distance = v:count ? v:count : 1

    if (col('.') - l:distance <= 1)
        silent normal! x0P
        return
    endif

    execute 'silent normal! x' . l:distance . 'hP'
endfunction

function! s:MoveCharRight()
    let l:distance = v:count ? v:count : 1

    if !g:move_past_end_of_line && (col('.') + l:distance >= col('$') - 1)
        silent normal! x$p
        return
    endif

    let [l:old_virtualedit, &virtualedit] = [&virtualedit, 'all']

    execute 'silent normal! x' . l:distance . 'lP'

    let &virtualedit = l:old_virtualedit
endfunction

function! s:MoveBlockNumDown(num) range
    call s:MoveBlockDown(a:firstline, a:lastline, a:num)
endfunction

function! s:MoveBlockNumUp(num) range
    call s:MoveBlockUp(a:firstline, a:lastline, a:num)
endfunction

" =====[ API ]===================================
vnoremap <silent> <Plug>MoveBlockDown           :call <SID>MoveBlockNumDown(1)<CR>
vnoremap <silent> <Plug>MoveBlockUp             :call <SID>MoveBlockNumUp(1)<CR>
vnoremap <silent> <Plug>MoveBlockHalfPageDown   :call <SID>MoveBlockNumDown(s:HalfWin())<CR>
vnoremap <silent> <Plug>MoveBlockHalfPageUp     :call <SID>MoveBlockNumUp(s:HalfWin())<CR>
vnoremap <silent> <Plug>MoveBlockLeft           :call <SID>MoveBlockLeft()<CR>
vnoremap <silent> <Plug>MoveBlockRight          :call <SID>MoveBlockRight()<CR>

nnoremap <silent> <Plug>MoveLineDown            :<C-u>call <SID>MoveLineDown(1)<CR>
nnoremap <silent> <Plug>MoveLineUp              :<C-u>call <SID>MoveLineUp(1)<CR>
nnoremap <silent> <Plug>MoveLineHalfPageDown    :<C-u>call <SID>MoveLineDown(s:HalfWin())<CR>
nnoremap <silent> <Plug>MoveLineHalfPageUp      :<C-u>call <SID>MoveLineUp(s:HalfWin())<CR>
nnoremap <silent> <Plug>MoveCharLeft            :<C-u>call <SID>MoveCharLeft()<CR>
nnoremap <silent> <Plug>MoveCharRight           :<C-u>call <SID>MoveCharRight()<CR>

function! s:UserWantMap(movement, mode)
    " In vim 8, v:t_number can be used instead of type(0) and v:t_dict instead
    " of type({}), but at the cost of losing compatibility with previous
    " versions
    if type(g:move_map_keys) == type(0)
        return g:move_map_keys != 0
    endif

    if type(g:move_map_keys) == type({})
        return g:move_map_keys[a:movement][a:mode] != 0
    endif
endfunction

if s:UserWantMap('vertical', 'visual')
    execute 'xmap' s:MoveKey('j') '<Plug>MoveBlockDown'
    execute 'xmap' s:MoveKey('k') '<Plug>MoveBlockUp'
endif

if s:UserWantMap('horizontal', 'visual')
    execute 'xmap' s:MoveKey('h') '<Plug>MoveBlockLeft'
    execute 'xmap' s:MoveKey('l') '<Plug>MoveBlockRight'
endif

if s:UserWantMap('vertical', 'normal')
    execute 'nmap' s:MoveKey('j') '<Plug>MoveLineDown'
    execute 'nmap' s:MoveKey('k') '<Plug>MoveLineUp'
endif

if s:UserWantMap('horizontal', 'normal')
    execute 'nmap' s:MoveKey('h') '<Plug>MoveCharLeft'
    execute 'nmap' s:MoveKey('l') '<Plug>MoveCharRight'
endif
