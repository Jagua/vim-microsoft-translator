" vim: set et fdm=marker ft=vim sts=2 sw=2 ts=2 :


scriptencoding utf-8


let s:save_cpo = &cpo
set cpo&vim


" The result is a String, which detected a language of {text}.
function! mstrans#detect(text) "{{{
  if mstrans#auth()
    let url = 'http://api.microsofttranslator.com/V2/Http.svc/Detect'
    let param = {'appId' : s:appId,
    \            'text' : a:text}
    let authToken = 'Bearer ' . s:config.access_token
    let res = webapi#http#get(url, param, {'Authorization' : authToken})
    if res.status == '200'
      return webapi#xml#parse(res.content).value()
    else
      return ''
    endif
  endif
endfunction "}}}


" The result is a Number, which is !0 if |String| {text} has
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
  if mstrans#auth()
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
    let authToken = 'Bearer ' . s:config.access_token
    let res = webapi#http#get(url, param, {'Authorization' : authToken})
    if res.status == '200'
      return webapi#xml#parse(res.content).value()
    endif
  endif
endfunction "}}}


" The result is a Number, which is !0 if got an access token, and 0 otherwise.
" An access token is set to {s:config}.
function! mstrans#auth() "{{{
  let s:appId = get(g:, 'mstrans_appid', '')
  let s:lang_to = get(g:, 'mstrans_to', 'ja')
  let s:lang_pair = get(g:, 'mstrans_pair', ['en', 'ja'])
  let s:client_id = get(g:, 'mstrans_client_id', '')
  let s:client_secret = get(g:, 'mstrans_client_secret', '')
  let s:config = {'access_token' : '', 'expires' : 0}
  let result = 0
  if (empty(s:client_id) || empty(s:client_secret)) && empty(s:appId)
    echoerr 'Error: Require g:mstrans_client_id and g:mstrans_client_secret (or g:mstrans_appid)'
  elseif !empty(s:client_id) && !empty(s:client_secret)
  \      && (empty(s:config.access_token) || s:config.expires < localtime())
    let ctx = {
    \ 'client_id' : webapi#http#encodeURI(s:client_id),
    \ 'client_secret' : webapi#http#encodeURI(s:client_secret),
    \ 'scope' : 'http://api.microsofttranslator.com',
    \ 'grant_type' : 'client_credentials',
    \ }
    let datamarket_access_uri =
    \ 'https://datamarket.accesscontrol.windows.net/v2/OAuth2-13'
    if !empty(ctx.client_id) && !empty(ctx.client_secret)
      let req = join(values(map(ctx, 'v:key . "=" . v:val . "&"')), '')[:-2]
      let res = webapi#http#post(datamarket_access_uri, req)
      if res.status == '200'
        let token = webapi#json#decode(res.content)
        let s:config.access_token = token.access_token
        let s:config.expires = localtime() + str2nr(token.expires_in)
        let s:appId = ''
        let result = !0
      endif
    endif
  elseif !empty(s:appId)
    let s:config.access_token = s:appId
    let result = !0
  endif
  return result
endfunction "}}}


let &cpo = s:save_cpo
unlet s:save_cpo

