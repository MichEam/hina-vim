"=============================================================================
" File: hina.vim
" Author: Michito Maeda <michito.maeda@gmail.com>
" Last Change: 2019-01-29.
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
command! EsaOpen call hina#posts#Edit()
command! EsaSave call hina#posts#Update()
command! EsaSync call hina#posts#Sync()
command! EsaNew  call hina#posts#New()

command! EsaInsertLink call hina#posts#InsertLink(0)
                          
let &cpo = s:save_cpo
unlet s:save_cpo
