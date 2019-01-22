"=============================================================================
" File: hina.vim
" Author: Michito Maeda <michito.maeda@gmail.com>
" Last Change: 2019-01-22.
" Version: 0.1
" WebPage: http://github.com/MichEam/hina-vim
" License: MIT
" script type: plugin
"=============================================================================

function! hina#Init() abort

    if !executable('curl')
        echohl ErrorMsg | echomsg 'Esa: require ''curl'' command' | echohl None
        finish
    endif

    if globpath(&rtp, 'autoload/webapi/http.vim') ==# ''
        echohl ErrorMsg | echomsg 'Esa: require ''webapi'', install https://github.com/mattn/webapi-vim' | echohl None
        finish
    endif

    let g:hina_working_dir = expand("~/.hina")

    " TODO: change scope to global.
    let g:hina_esa_api_version = 'v1'
    let g:hina_esa_host        = 'https://api.esa.io/' . g:hina_esa_api_version . '/teams'

    let g:hina_conf_file       = "config.json"
    " TODO: need to reload conf per proc.
    let g:hina_conf_json       = join(readfile(g:hina_working_dir . "/" . g:hina_conf_file), '')
    let g:hina_confmap         = json_decode(g:hina_conf_json)
    let g:hina_default_team    = g:hina_confmap["default-team"]

    let g:hina_initialized = 1
endfunction

function! hina#ListTeams(ArgLead, CmdLine, CursorPos)
	" ArgLead		すでに入力されている補完対象の文字列
	" CmdLine		コマンドライン全体
	" CursorPos	カーソル位置 (バイト単位のインデックス)
    let _ = s:getTeamList()
    return _
endfunction

