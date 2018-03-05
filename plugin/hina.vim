"=============================================================================
" File: hina.vim
" Author: Michito Maeda <michito.maeda@gmail.com>
" Last Change: 2018-03-05.
" Version: 0.1
" WebPage: http://github.com/MichEam/hina-vim
" License: MIT
" script type: plugin

if &compatible || (exists('g:loaded_hina_vim') && g:loaded_hina_vim)
  finish
endif
let g:loaded_hina_vim = 1

function! s:CompleteArgs(arg_lead,cmdline,cursor_pos)
    return filter(copy(["-b", "-c", "-p", "-w", "--browser", "--clipboard", "--public", "--wip"
                \ ]), 'stridx(v:val, a:arg_lead)==0')
endfunction

command! -nargs=? -range=% -bang -complete=customlist,s:CompleteArgs Hina :call hina#(<count>, "<bang>", <line0>, <line2>, <f-args>)
