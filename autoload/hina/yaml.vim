function! hina#yaml#Encode(lines) abort
    let obj = {}

    for line in a:lines
        let key = matchstr(line, '^\w.*\ze:\s')
        let val = matchstr(line, key.': \zs.*')
        let obj[key] = val
    endfor

    return obj
endfunction

function! hina#yaml#Decode(obj) abort
    let lines = []
    
    for key in keys(a:obj) 
        let line = key.": ".a:obj[key]
        call add(lines, line)
        "echom line
    endfor

    return lines
endfunction

