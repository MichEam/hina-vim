"=============================================================================
" File: hina.vim
" Author: Michito Maeda <michito.maeda@gmail.com>
" Last Change: 2018-03-13.
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

" == ROAD MAP ==
"
" | コマンド    | エイリアス | 引数      | 説明                                     |
" +-------------+------------+-----------+------------------------------------------+
" | HinaEdit    | hina       | ${number} | 既存の記事の編集を開始する               |
" | HinaEditNew | hinanew    |           | 新規記事の編集を開始する                 |
" | HinaWrite   | hinaw      |           | 編集中の記事を保存する(esa.ioへのポスト) |
" | HinaOpen    | hinao      |           | 編集中の記事をブラウザで開く             |

let &cpo = s:save_cpo
unlet s:save_cpo
