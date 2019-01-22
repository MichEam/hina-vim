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
    let _ = s:getTeamList()
    return _
endfunction

function! hina#PostsEdit() abort
    if !exists('g:hina_initialized')
        call hina#Init()
    endif
    
    let team = input('team ? : ', s:default_team, "customlist,hina#ListTeams")
    let number = input('number ? :')

    try
        let content = s:getContent(team, number)
    catch /.*/
        return 1
    endtry

    let body_md_lines = split(content.body_md, "\r\n")

    try
        :enew
    catch /.*/
        :vs | wincmd L | enew
    endtry

    let b:org_body_md = content.body_md
    let b:team = team
    :set ft=markdown
    
    let headerLines = s:createHeaderLines(content)
    let b:hina_header_start = 1
    let b:hina_header_end = len(headerLines)

    call setline(1, headerLines)
    call append(line('$'), body_md_lines)
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
    let content = s:getPost(team, name, category)

    :1,$d
    :set ft=markdown

    let b:org_body_md = content.body_md
    let headerLines = s:createHeaderLines(content)
    let b:hina_header_start = 1
    let b:hina_header_end = len(headerLines)
    let b:team = team

    call setline(1, headerLines)
    call append(line('$'), split(content.body_md, "\r\n"))

    call s:showMessage("new Post created ! number:".content.number)
    return 0
endfunction

function! hina#PostsPush() abort 

    if !exists('g:hina_initialized')
        call hina#Init()
    endif

    " patch content to server
    let meta = s:readHeader()
    let content = s:patchContent(b:team, meta)

    call s:showMessage("Patched! revision:".content.revision_number)

    let b:org_body_md = content.body_md
    let headerLines = s:createHeaderLines(content)
    let b:hina_header_start = 1
    let b:hina_header_end = len(headerLines)

    :1,$d

    call setline(1, headerLines)
    call append(line('$'), split(content.body_md, "\r\n"))

    return 0
endfunction 

function! s:readHeader() abort
    let headerLines = getline(b:hina_header_start+1, b:hina_header_end-1)
    let _ = hina#yaml#Encode(headerLines)
    return _
endfunction

function! s:createHeaderLines(content) abort
    let _ = ["---"]
    let metaInfo = s:getMetaInfo(a:content)
    let metaLines = hina#yaml#Decode(metaInfo)
    call extend(_, metaLines)
    call add(_, "---")
    call add(_, "")
    return _
endfunction

function! s:getMetaInfo(content) abort
    " @see 
    " https://docs.esa.io/posts/102#記事
    let c = a:content
    let _ = {}
    let _.name      = c.name
    let _.category  = c.category
    let _.tags      = '[' . join(c.tags, ',') . ']'
    let _.created   = c.created_at." ".c.created_by.name
    let _.updated   = c.updated_at." ".c.updated_by.name
    let _.wip       = c.wip
    let _.number    = c.number
    let _.revision  = c.revision_number
    return _
endfunction

function! s:getPost(team, name, category) abort
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

function! s:patchContent(team, meta) abort
    let body = join(getline(b:hina_header_end+1,'$'), "\n")
    let post = { "post" : {
                \    "body_md"           : body,
                \    "original_revision" : {
                \      "body_md" : b:org_body_md,
                \      "number"  : a:meta.revision
                \    }
                \ }}

    let header = s:buildHeader(a:team)
    let url = s:esa_host . '/' . a:team . '/posts/' . a:meta.number
    let res = webapi#http#post(url, json_encode(post), header, 'PATCH')

    if res.status !~ "^2.."
        call s:showError(''.res.status.':'.res.message.':'.url)
        throw "Faild to get content."
    endif

    let content = json_decode(res.content)
    return content
endfunction

function! s:getContent(team, number) abort

    let header = s:buildHeader(a:team)
    let url = s:esa_host . '/' . a:team . '/posts/' . a:number
    let response = webapi#http#get(url, "", header)

    if response.status !~ "^2.."
        call s:showError(''.response.status.':'.response.message.':'.url)
        throw "Faild to get content."
    endif

    let content = json_decode(response.content)
    return content
endfunction

function! s:getToken(team) abort

    let conflist = copy(s:confmap['conflist'])
    let filterd_conflist = filter(conflist, {i,v -> v.team == a:team})

    if !len(filterd_conflist)
        throw "Illegal State. Cant find token for team:".a:team
    endif

    return filterd_conflist[0].token

endfunction

function! s:getTeamList() abort

    let conflist = s:confmap['conflist']
    let teamlist = []

    for conf in conflist
        call add(teamlist, conf['team'])
    endfunctionor

    return teamlist

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

function! s:showError(msg) abort
    echohl ErrorMsg | echomsg "(T⊖T) < ".a:msg | echohl None
endfunction 

function! s:strftime(fmt) abort
    if exists("*strftime")
        return strftime(a:fmt)
    else
        return ""
    endif
endfunction
