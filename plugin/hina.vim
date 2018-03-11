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

if exists('g:hina_loaded')
    finish
endif
let g:hina_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

" vim script
command! EsaPush call hina#PostsPush()
command! EsaPull call hina#PostsPush()

let &cpo = s:save_cpo
unlet s:save_cpo
