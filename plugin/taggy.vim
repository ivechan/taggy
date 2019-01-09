function Taggy_Key_Func(x, y)
    return len(a:y['name']) - len(a:x['name'])
endfunction

function Taggy_CloseHandler(channel)
    let l = []
    let b:taggy_dict = {}
    while ch_status(a:channel, {'part':'out'}) == 'buffered'
        let item = json_decode(ch_read(a:channel))
        if !empty(item)
            call add(l, item)
            if has_key(item, 'line') 
                if has_key(b:taggy_dict, item.line)
                    let old_name = b:taggy_dict[item.line]
                    let new_name = item.name
                    if len(new_name) > len(old_name)
                        let b:taggy_dict[item.line] = item
                    endif
                else
                    let b:taggy_dict[item.line] = item
                endif
            endif
        endif
    endwhile
    let b:taggylist = l
    let b:taggy_isrunning = 0
endfunction

function Taggy_ErrHandler(channel, msg)
    let b:taggy_isrunning = 0
    echo 'Error from taggy channel.'
endfunction

function Taggy_Update_Vimscript()
    let filename = expand('%:p')
    if filename != '' && filereadable(filename)
        if exists('b:taggy_isrunning') && b:taggy_isrunning == 1
            " tag update task is still running.
            return
        endif
        let b:taggy_isrunning = 1
        let cmd = 'ctags --fields=* -f - --extras=+q --output-format=json ' . filename
        let job = job_start(cmd, {"close_cb": "Taggy_CloseHandler", 'err_cb':"Taggy_ErrHandler"})
    endif

endfunction

function Taggy_Get_Current_Tag()
    let filename = expand('%:p')
    if filename == '' || !filereadable(filename)
        return ''
    endif
    if !exists('b:taggy_dict')
        " taggy_dict does not exist, perform a tag updating task.
        call Taggy_Update_Vimscript()
        return ""
    else 
        "echo 'taggy_dict exists.'
    endif
    " let s:taggy_dict = b:taggy_dict
    let s:cur_line = line('.')
    let s:match_list = []
    let s:ret = ''
    if !empty(b:taggy_dict)
        for line in range(s:cur_line, 1, -1)
            if has_key(b:taggy_dict, line) && get(b:taggy_dict[line], 'end', 99999999) >= s:cur_line
                let s:ret = b:taggy_dict[line].name

                break
            endif
        endfor
    endif
    return s:ret

endfunction

augroup Taggy
    autocmd!
    " au BufEnter * call Taggy_Update()
    au BufReadPost * call Taggy_Update_Vimscript()
    au BufWritePost * call Taggy_Update_Vimscript()
augroup END
