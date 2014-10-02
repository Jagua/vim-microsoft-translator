" vim: set et fdm=marker ft=vim sts=2 sw=2 ts=2 :


scriptencoding utf-8


let s:save_cpo = &cpo
set cpo&vim


let s:appId = get(g:, 'mstrans_appid', 0)

let s:lang_to = get(g:, 'mstrans_to', 'ja')

let s:lang_pair = get(g:, 'mstrans_pair', ['en', 'ja'])


" The result is a Number, which is 0! if appId is set, and 0 otherwise.
function! s:has_appId() "{{{
  if s:appId == 0
    echoerr 'microsoft-translator requires g:mstrans_appid.'
    return 0
  else
    return !0
  endif
endfunction "}}}


" The result is a String, which detected a language of {text}.
function! mstrans#detect(text) "{{{
  if s:has_appId()
    let url = 'http://api.microsofttranslator.com/V2/Http.svc/Detect'
    let param = {'appId' : s:appId,
    \            'text' : a:text}
    let authToken = 'Bearer ' . s:appId
    let res = webapi#http#get(url, param, {'Authorization' : authToken})
    if (res.status == '200')
      return webapi#xml#parse(res.content).value()
    endif
  endif
endfunction "}}}


" The result is a Number, which is 0! if |String| {text} has
" Hiragana or Katakana, and 0 otherwise.
function! mstrans#has_kana(text) "{{{
  return match(a:text, '[\u3041-\u309f\u30a1-\u30ff\u31f0-\u31ff\u1b000-\u1b0ff]') > -1
endfunction "}}}


" The result is a String. If s:lang_pair has {from}, return the other,
" otherwise return {to}.
function! mstrans#_to(from, to) "{{{
  let idx = index(s:lang_pair, a:from)
  let to = (idx >= 0 ? s:lang_pair[(idx + 1) % 2] : a:to)
  return to
endfunction "}}}


" The result is a String, which translated {text} from {from} to {to}.
" Omitting {from} and {to}, guess them by {text} and mstrans_* variables.
" mstrans#translate({text} [, {from}, {to}])
function! mstrans#translate(text, ...) "{{{
  if s:has_appId()
    if a:0 == 2
      let from = a:000[0]
      let to = a:000[1] == '' ? s:lang_to : a:000[1]
    elseif a:0 == 0
      let from = ''
      let to = s:lang_to
      if match(a:text, '^[\u0001-\u007e]\+$') > -1
        let from = 'en'
        let to = mstrans#_to(from, to)
      elseif mstrans#has_kana(a:text)
        let from = 'ja'
        let to = mstrans#_to(from, to)
      endif
    endif
    let url = 'http://api.microsofttranslator.com/V2/Http.svc/Translate'
    let param = {'appId' : s:appId,
    \            'text' : a:text,
    \            'to' : to,
    \            'contentType' : 'text/plain'}
    if from != ''
      let param.from = from
    endif
    let authToken = 'Bearer ' . s:appId
    let res = webapi#http#get(url, param, {'Authorization' : authToken})
    if (res.status == '200')
      return webapi#xml#parse(res.content).value()
    endif
  endif
endfunction "}}}


let &cpo = s:save_cpo
unlet s:save_cpo

