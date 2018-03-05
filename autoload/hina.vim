"=============================================================================
" File: hina.vim
" Author: Michito Maeda <michito.maeda@gmail.com>
" Last Change: 2018-03-05.
" Version: 0.1
" WebPage: http://github.com/MichEam/hina-vim
" License: MIT
" script type: plugin
"=============================================================================

" FUNCTIONS 
"=======================
" public 
"------
function! hina#PostCreate(name, body, category) abort 
    let post = {"post" : {"name" : a:name, "body_md" : a:body, "category" : a:category }}
    let header = s:buildHeader()
    let url = g:esa_host . '/posts'
    let res = webapi#http#post(url, json_encode(post), header)
    let obj = json_decode(res.content)
    call s:showMessage('new post created : ' . obj.url)
    return 0
endfunction 

" private 
"-------
function! s:buildHeader() 
    let _ = {}
    let _['Content-Type']  = "application/json"
    let _['Authorization'] = 'Bearer ' . g:esa_token
    return _
endfunction 

function! s:buildMsg(msg) 
    return "[HINA] " . a:msg
endfunction 

function! s:showMessage(msg) 
    echohl Normal | echomsg s:buildMsg(a:msg) | echohl None
endfunction 

function! s:showWarn(msg) 
    echohl WarningMsg | echomsg s:buildMsg(a:msg) | echohl None
endfunction 

function! s:showError(msg) 
    echohl ErrorMsg | echomsg s:buildMsg(a:msg) | echohl None
endfunction 

" MAIN PROC 
"=======================

" Check dependencies 
"------------------
if !executable('curl')
    echohl ErrorMsg | echomsg 'Esa: require ''curl'' command' | echohl None
    finish
endif

if globpath(&rtp, 'autoload/webapi/http.vim') ==# ''
    echohl ErrorMsg | echomsg 'Esa: require ''webapi'', install https://github.com/mattn/webapi-vim' | echohl None
    finish
endif

" Global variables 
"------------------
let g:esa_api_version = 'v1'
let g:esa_host = 'https://api.esa.io/' . g:esa_api_version . '/teams'

let g:hina_working_dir = expand("~/.hina")
let g:hina_conf_file    = "config.json"

" Appication configs 
"------------------
" read config file
let s:conf_json = join(readfile(g:hina_working_dir . "/" . g:hina_conf_file), '')
let conf = json_decode(s:conf_json)
let g:esa_host = g:esa_host . "/" . g:conf.team
let g:esa_token = conf.token

