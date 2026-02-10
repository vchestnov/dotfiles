" " Make align a full math zone (like equation)
" syn region texMathZoneC start='\\begin{\(align\|align\*\)}' end='\\end{\(align\|align\*\)}' keepend contains=@texMathZoneGroup
" " syn region texRefZone matchgroup=texStatement start=/\\cref{/ end=/}\|%stopzone\>/  contains=@texRefGroup
" syn region texRefZone matchgroup=texStatement start=/\\\(cref\|labelcref\|namecref\|pagecref\){/ end=/}\|%stopzone\>/ contains=@texRefGroup

" Make align a full math zone (like equation) — also inside other regions/macros
silent! syn clear texMathZoneC
syn region texMathZoneC
  \ start='\\begin{\(align\|align\*\)}'
  \ end='\\end{\(align\|align\*\)}'
  \ keepend
  \ contains=@texMathZoneGroup
  \ containedin=ALL

syn region texMathZoneEquationC
  \ start='\\begin{\(equation\|equation\*\)}'
  \ end='\\end{\(equation\|equation\*\)}'
  \ keepend
  \ contains=@texMathZoneGroup
  \ containedin=ALL

silent! syn clear texRefZone
syn region texRefZone
  \ matchgroup=texStatement
  \ start=/\\\(cref\|labelcref\|namecref\|pagecref\|label\){/
  \ end=/}\|%stopzone\>/
  \ keepend
  \ contains=@texRefGroup
  \ containedin=ALL
