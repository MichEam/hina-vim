"=============================================================================
" File: posts.vim
" Author: Michito Maeda <michito.maeda@gmail.com>
" Last Change: 2019-02-13.
" Version: 0.1
" WebPage: http://github.com/MichEam/hina-vim
" License: MIT
" script type: plugin
"=============================================================================

" カーソル位置に投稿リンクを埋め込む
function! hina#posts#InsertLink(insertMode) abort
    let _ = hina#posts#GetPostLink()
    execute ":normal a" . _
    if a:insertMode
        execute ":startinsert"
        call cursor(line("."), col(".")+1)
    endif
endfunction

function! hina#posts#GetPostLink() abort
    if !exists('g:hina_initialized') | call hina#Init() | endif

    try
        let team = s:readHeader()['team']
    catch /HeaderNotExists/ 
        let team = input('team: ', g:hina_default_team, "customlist,hina#ListTeams")
    endtry
    let number = input('reference post number:')

    let content = s:getContent(team, number)
    let fullName = content['full_name']

    return printf('[#%d:%s](/posts/%d)', number, fullName, number)
endfunction

function! hina#posts#Edit() abort
    if !exists('g:hina_initialized') | call hina#Init() | endif
    
    let team = input('team ? : ', g:hina_default_team, "customlist,hina#ListTeams")
    let number = input('number ? :')

    try
        let content = s:getContent(team, number)
    catch /.*/
        return 1
    endtry

    let splitted_body = hina#SplitBody(content.body_md)

    if input('新規バッファに読み込みますか? [y/n]: ', 'y') == 'y'
        try
            :enew
        catch /.*/
            :vs | wincmd L | enew
        endtry
    endif

    :1,$d

    let b:org_body_md = content.body_md
    let b:team = team
    :set ft=markdown
    
    let headerLines = s:createHeaderLines(content, team)

    call setline(1, headerLines)
    call append(line('$'), splitted_body)
endfunction

function! hina#posts#New() abort

    if !exists('g:hina_initialized') | call hina#Init() | endif
    if exists("b:content") && input('save as new Posts? (Y/N): ') != "Y"
        return 1
    endif

    " TODO: delete. date is include category, maybe.
    let time = s:strftime("%Y-%m-%d_")

    let team = input('which team ? : ', g:hina_default_team, "customlist,hina#ListTeams")
    let name = input('post name ? :', time)

    let categoryFmt = s:getDefaultCategory(team)
    let category = s:convCategory(categoryFmt)
    let content = s:post(team, name, category)

    :1,$d
    :set ft=markdown

    let b:org_body_md = content.body_md
    let headerLines = s:createHeaderLines(content, team)
    let b:team = team

    call setline(1, headerLines)
    let splitted_body = hina#SplitBody(content.body_md)
    call append(line('$'), splitted_body)

    call hina#Msg("new Post created ! number:".content.number)
    return 0
endfunction

function! hina#posts#Update() abort 

    if !exists('g:hina_initialized') | call hina#Init() | endif

    " patch content to server
    let meta = s:readHeader()

    if !exists('b:team') || !exists('b:org_body_md')
        call hina#Warn('このバッファはesa.ioと同期されていません。`:EsaSync` を実行してからやり直してください')
        return 1
    endif
        
    let team = b:team
    let content = s:patchContent(team, meta)

    call hina#Msg("Patched! revision:".content.revision_number)

    let b:org_body_md = content.body_md
    let headerLines = s:createHeaderLines(content, team)

    :1,$d
    call setline(1, headerLines)
    let splitted_body = hina#SplitBody(content.body_md)
    call append(line('$'), splitted_body)

    return 0
endfunction 

function! hina#posts#Sync() abort
    if !exists('g:hina_initialized') | call hina#Init() | endif

    let team = input('which team ? : ', g:hina_default_team, "customlist,hina#ListTeams")
    if team == ''
        return 0
    endif

    let metaInfo = s:readHeader()
    let number = metaInfo['number']
    let revision = metaInfo['revision']
    let content = s:getContent(team, number)

    if revision != content['revision_number']
        call hina#Error('残念ながら、その記事はesa.ioで更新されています。:EsaOpenしてやり直してくださいぃ')
        return 1
    endif

    let b:team = team
    let b:org_body_md = content['body_md']

    call hina#Msg(printf("バッファを記事:%s, リビジョン:%d と同期しました。", number, revision))
    return 0
endfunction

function! s:headerEnd() abort
    let current_line = line('.')
    let current_col = col('.')

    call cursor(2,1)
    let e = search("^---")

    call cursor(current_line, current_col)
    return e
endfunction

function! s:readHeader() abort
    let start = 1
    let end = s:headerEnd()
    if getline(1) != '---' || end == 0 | throw "HeaderNotExists" | endif

    let headerLines = getline(start+1, end-1)
    let _ = hina#yaml#Encode(headerLines)
    if !_['number'] | throw "HeaderNotExists" | endif
    return _
endfunction

function! s:createHeaderLines(content, team) abort
    let _ = ["---"]
    let metaInfo = s:toMetaInfo(a:content, a:team)
    let metaLines = hina#yaml#Decode(metaInfo)
    call extend(_, metaLines)
    call add(_, "---")
    return _
endfunction

function! s:toMetaInfo(content, team) abort
    " @see 
    " https://docs.esa.io/posts/102#記事
    let c = a:content
    let _ = {}
    let _.team      = a:team
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

function! s:post(team, name, category) abort
    let body = join(getline(1,'$'), "\r\n")
    let post = { "post" : {
                \    "body_md"           : body,
                \    "name"              : a:name,
                \    "category"          : a:category
                \ }}

    let header = s:buildHTTPHeader(a:team)
    let url = g:hina_esa_host . '/' . a:team . '/posts'
    let res = webapi#http#post(url, json_encode(post), header)

    if res.status !~ "^2.."
        call hina#Error(''.res.status.':'.res.message.':'.url)
        return 1
    endif

    let content = json_decode(res.content)
    return content
endfunction

function! s:patchContent(team, meta) abort
    let body = join(getline(s:headerEnd()+1 ,'$'), "\r\n")
    let post = { "post" : {
                \    "body_md"           : body,
                \    "original_revision" : {
                \      "body_md" : b:org_body_md,
                \      "number"  : a:meta.revision
                \    }
                \ }}

    let header = s:buildHTTPHeader(a:team)
    let url = g:hina_esa_host . '/' . a:team . '/posts/' . a:meta.number
    let res = webapi#http#post(url, json_encode(post), header, 'PATCH')

    if res.status !~ "^2.."
        call hina#Error(''.res.status.':'.res.message.':'.url)
        throw "Faild to get content."
    endif

    let content = json_decode(res.content)
    return content
endfunction

function! s:getContent(team, number) abort

    let header = s:buildHTTPHeader(a:team)
    let url = g:hina_esa_host . '/' . a:team . '/posts/' . a:number
    let response = webapi#http#get(url, "", header)

    if response.status !~ "^2.."
        call hina#Error(''.response.status.':'.response.message.':'.url)
        throw "Faild to get content."
    endif

    let content = json_decode(response.content)
    return content
endfunction

" TODO: move to autoload/config/hina.vim
function! s:getToken(team) abort

    let conflist = copy(g:hina_confmap['conflist'])
    let filterd_conflist = filter(conflist, {i,v -> v.team == a:team})

    if !len(filterd_conflist)
        throw "Illegal State. Cant find token for team:".a:team
    endif

    return filterd_conflist[0].token

endfunction

" TODO: move to autoload/config/hina.vim
function! s:getTeamList() abort

    let conflist = g:hina_confmap['conflist']
    let teamlist = []

    for conf in conflist
        call add(teamlist, conf['team'])
    endfunctionor

    return teamlist

endfunction

" TODO: move to autoload/config/hina.vim
function! s:getDefaultCategory(team) abort
    let conflist = g:hina_confmap['conflist']
    let fltdConflist = filter(copy(conflist), {i,e -> e.team == a:team})

    if has_key(fltdConflist[0], "categoryFmt")
        return fltdConflist[0]["categoryFmt"]
    endif

    return ""
endfunction

" TODO: move to autoload/hina.vim
function!  s:convCategory(categoryFmt) abort
    " TODO: 外部から指定できた方が嬉しい？
    let timeFmt = "%[Yymd]"
    if match(a:categoryFmt, timeFmt)
        return strftime(a:categoryFmt)
    else
        string(a:categoryFmt)
    endif
endfunction

function! s:buildHTTPHeader(team)  abort
    let _ = {}
    let _['Content-Type']  = "application/json"
    let _['Authorization'] = 'Bearer ' . s:getToken(a:team)
    return _
endfunction 

" TODO: move to autoload/hina/util.vim
function! s:strftime(fmt) abort
    if exists("*strftime")
        return strftime(a:fmt)
    else
        return ""
    endif
endfunction
