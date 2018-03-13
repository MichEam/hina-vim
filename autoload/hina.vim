"=============================================================================
" File: hina.vim
" Author: Michito Maeda <michito.maeda@gmail.com>
" Last Change: 2018-03-13.
" Version: 0.1
" WebPage: http://github.com/MichEam/hina-vim
" License: MIT
" script type: plugin
"=============================================================================

" FUNCTIONS 
"=======================
" public 
"------
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

    let s:hina_conf_file  = "config.json"
    let s:esa_api_version = 'v1'
    let s:esa_host        = 'https://api.esa.io/' . s:esa_api_version . '/teams'
    let s:conf_json       = join(readfile(g:hina_working_dir . "/" . s:hina_conf_file), '')
    let s:confmap         = json_decode(s:conf_json)
    let s:default_team    = s:confmap["default-team"]

    let g:hina_initialized = 1
endfunction

function! hina#ListTeams(ArgLead, CmdLine, CursorPos)
	" ArgLead		すでに入力されている補完対象の文字列
	" CmdLine		コマンドライン全体
	" CursorPos	カーソル位置 (バイト単位のインデックス)
    return s:teamlist
endfunction

function! hina#PostsNew() abort

    if !exists('g:hina_initialized')
        call hina#Init()
    endif

    if exists("b:content") && input('push as new Posts? (Y/N): ') != "Y"
        return 1
    endif

    let time = s:strftime("%Y-%m-%d_")

    let team = input('which team ? : ', s:default_team, "customlist,hina#ListTeams")
    let name = input('post name ? :', time)

    let categoryFmt = s:getDefaultCategory(team)
    let category = s:convCategory(categoryFmt)
    let b:content = s:postContent(team, name, category)

    call s:showMessage("new Post created ! number:".b:content.number)
    return 0
endfunction

function! hina#PostsPush() abort 

    if !exists('g:hina_initialized')
        call hina#Init()
    endif

    " check if Post content has pulled.
    if !exists("b:content")
        call s:showError("Please pull post content first ==> :call hina#PostsPull()")
        return 1
    endif

    " detect team and post number.
    let team = s:detectPostTeam()
    let number = s:detectPostNumber()

    " patch content to server
    let b:content = s:patchContent(team, number)

    call s:showMessage("Patched! revision:".b:content.revision_number)
    return 0
endfunction 

" current bufferをesa.ioと同期する。
function! hina#PostsPull() abort
    if !exists('g:hina_initialized')
        call hina#Init()
    endif
    
    " detect team and post number.
    let team = s:detectPostTeam()
    let number = s:detectPostNumber()
    
    " get latest content of posts.
    let b:content = s:getContent(team, number)

    " reflesh buffer content.
    let body_md_lines = split(b:content.body_md, "\n")
    :1,$d " delete all line.
    call setline('.', body_md_lines)
endfunction

" private 
"-------

" file pathからteamを特定する
" foo/bar/tiger/93.md => tiger
function! s:detectPostTeam() abort
    let parent_path = expand('%:p:h')
    let grandparent_path = expand('%:p:h:h')
    let parent_name = substitute(parent_path, grandparent_path, "", "")
    return substitute(parent_name, "^\/", "", "")
endfunction

" file nameからpost number を特定する
" foo/bar/tiger/93.md => 93
function! s:detectPostNumber() abort
    return expand('%:t:r')
endfunction

function! s:postContent(team, name, category) abort
    let body = join(getline(1,'$'), "\n")
    let post = { "post" : {
                \    "body_md"           : body,
                \    "name"              : a:name,
                \    "category"          : a:category
                \ }}

    let header = s:buildHeader(a:team)
    let url = s:esa_host . '/' . a:team . '/posts'
    let res = webapi#http#post(url, json_encode(post), header)

    if res.status !~ "^2.."
        call s:showError(''.res.status.':'.res.message.':'.url)
        return 1
    endif

    let content = json_decode(res.content)
    return content
endfunction

function! s:patchContent(team, number) abort
    let body = join(getline(1,'$'), "\n")
    let post = { "post" : {
                \    "body_md"           : body,
                \    "original_revision" : {
                \      "body_md" : b:content.body_md,
                \      "number"  : b:content.revision_number,
                \      "user"    : b:content.updated_by.screen_name
                \    }
                \ }}

    let header = s:buildHeader(a:team)
    let url = s:esa_host . '/' . a:team . '/posts/' . a:number
    let res = webapi#http#post(url, json_encode(post), header, 'PATCH')

    if res.status !~ "^2.."
        call s:showError(''.res.status.':'.res.message.':'.url)
        return 1
    endif

    let content = json_decode(res.content)
    return content
endfunction

function! s:getContent(team, number) abort

    let header = s:buildHeader(a:team)
    let url = s:esa_host . '/' . a:team . '/posts/' . a:number
    let res = webapi#http#get(url, "", header)

    if res.status !~ "^2.."
        call s:showError(''.res.status.':'.res.message.':'.url)
        return 1
    endif

    let content = json_decode(res.content)
    return content
endfunction

function! s:getToken(team) abort
    let conflist = s:confmap['conflist']
    let filterd_conflist = filter(copy(conflist), {i,v -> v.team == a:team})

    if !len(filterd_conflist)
        throw "Illegal State. Cant get Token. team:".a:team
    endif

    return filterd_conflist[0].token
endfunction

function! s:getDefaultCategory(team) abort
    let conflist = s:confmap['conflist']
    let fltdConflist = filter(copy(conflist), {i,e -> e.team == a:team})

    if has_key(fltdConflist[0], "categoryFmt")
        return fltdConflist[0]["categoryFmt"]
    endif

    return ""
endfunction

function!  s:convCategory(categoryFmt) abort
    " TODO: 外部から指定できた方が嬉しい？
    let timeFmt = "%[Yymd]"
    echo string(a:categoryFmt)
    if match(a:categoryFmt, timeFmt)
        return strftime(a:categoryFmt)
    else
        string(a:categoryFmt)
    endif
endfunction

function! s:buildHeader(team)  abort
    let _ = {}
    let _['Content-Type']  = "application/json"
    let _['Authorization'] = 'Bearer ' . s:getToken(a:team)
    return _
endfunction 

function! s:showMessage(msg)  abort
    echohl Normal | echomsg "(⁰⊖⁰) .oO( ".a:msg." )" | echohl None
endfunction 

function! s:showWarn(msg)  abort
    echohl WarningMsg | echomsg "(•᷄ө•᷅) .oO( ".a:msg." )" | echohl None
endfunction 

function! s:showError(msg)  abort
    echohl ErrorMsg | echomsg "(T⊖T) < ".a:msg | echohl None
endfunction 

function! s:strftime(fmt) abort
    if exists("*strftime")
        return strftime(a:fmt)
    else
        return ""
    endif
endfunction
