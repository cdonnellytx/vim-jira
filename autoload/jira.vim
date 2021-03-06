"=============================================================================
" File: jira.vim
" Author: Jemma Nelson <pink.fwip@gmail.com>
" WebPage: http://github.com/Fwip/vim-jira
" License: BSD
" script type: plugin
"

" Prompt user if we need info
function! jira#GetCredentials()
  if !exists('g:vim_jira_url')
    let g:vim_jira_url = input("JIRA url? ")
  endif
  if !exists('g:vim_jira_user')
    let g:vim_jira_user = input("JIRA user? ")
  endif
  if !exists('g:vim_jira_pass')
    let g:vim_jira_pass = inputsecret("JIRA password? ")
  endif
  let g:vim_jira_rest_url = g:vim_jira_url . '/rest/api/2/'
endfunction

" Grab issue from the server
function! jira#GetIssue(id)
  call jira#GetCredentials()
  let url = g:vim_jira_rest_url . 'issue/' . a:id
  let cmd = 'curl '. url .' -s -k -u '. g:vim_jira_user .':'. g:vim_jira_pass

  let data_json = system(cmd)

  let g:jira_current_issue = json_encoding#Decode(data_json)

  return g:jira_current_issue
endfunction

function! jira#PostDescription(id, description)
  call jira#GetCredentials()
  let url = g:vim_jira_rest_url . 'issue/' . a:id
  let tmpfile = '/tmp/tmpjirafile-' . a:id

  let data = json_encoding#Encode({"fields": {"description": a:description }})
  " Wow, this took way too long to figure out.
  " Un-encode newlines so Jira accepts it.
  let datafix = substitute(data, '\\\\n', '\\n', 'g')
  call writefile([datafix], tmpfile)
  let cmd = 'curl -X PUT '. url .' --data @'. tmpfile .' -H "Content-Type: application/json" -s -k -u '. g:vim_jira_user .':'. g:vim_jira_pass 
  " TODO: Error handling
  let result = system(cmd)
endfunction

function! jira#PostBuffer()
  let newdesc = join(getline(1,'$'), '\n')
  call jira#PostDescription(b:issue.key, newdesc)
  set nomodified
endfunction

" Extract an issue's description as an array of lines
function! jira#GetDesc(issue)
  " Can be encoded as \r\n, or \n. I put \r in there for safety
  return split(a:issue.fields.description, '\r\n\|[\r\n]')
endfunction

function! jira#CycleStatusIndicator()
  if (! exists('g:jira_status_icons'))
    let g:jira_status_icons = ['(off)', '(on)', '(/)', '(!)', '(?)', '(n)', '(y)']
  endif

  let word = expand('<cWORD>')
  let index = 0
  for i in g:jira_status_icons
    let index += 1
    if (i == word)
      let next_word = g:jira_status_icons[ index - len(g:jira_status_icons) ]
      execute 'normal! ciW' . next_word
    endif
  endfor

endfunction

function! jira#Browse()
  call jira#GetCredentials()
endfunction

" Open up a new split with the given issue
function! jira#OpenBuffer(id)
  let issue = jira#GetIssue(a:id)

  let tmpfile = '/tmp/vim-jira-' . issue.key . '-desc.jira'
  call writefile(jira#GetDesc(issue), tmpfile)
  execute 'vsplit ' . tmpfile
  execute 'set ft=jira'
  let b:issue = issue
  autocmd BufWriteCmd <buffer> call jira#PostBuffer()

endfunction
