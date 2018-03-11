"=============================================================================
" File: hina.vim
" Author: Michito Maeda <michito.maeda@gmail.com>
" Last Change: 2018-03-11.
" Version: 0.1
" WebPage: http://github.com/MichEam/hina-vim
" License: MIT
" script type: plugin
"=============================================================================

scriptencoding utf-8

if exists('g:loaded_hina')
    finish
endif
let g:loaded_hina = 1

let s:save_cpo = &cpo
set cpo&vim

" vim script
command! EsaPush call hina#PostsPush()
command! EsaPull call hina#PostsPull()

let &cpo = s:save_cpo
unlet s:save_cpo
