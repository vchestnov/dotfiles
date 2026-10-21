" " Make align a full math zone (like equation)
" syn region texMathZoneC start='\\begin{\(align\|align\*\)}' end='\\end{\(align\|align\*\)}' keepend contains=@texMathZoneGroup
" " syn region texRefZone matchgroup=texStatement start=/\\cref{/ end=/}\|%stopzone\>/  contains=@texRefGroup
" syn region texRefZone matchgroup=texStatement start=/\\\(cref\|labelcref\|namecref\|pagecref\){/ end=/}\|%stopzone\>/ contains=@texRefGroup

" Make align a full math zone (like equation) — also inside other regions/macros
" Exclude the spellchecking wrapper too: containedin checks only the immediate
" parent, which may be texCommandNoSpell inside a comment.
silent! syn clear texMathZoneC
syn region texMathZoneC
  \ start='\\begin{\(align\|align\*\)}'
  \ end='\\end{\(align\|align\*\)}'
  \ keepend
  \ contains=@texMathZoneGroup
  \ containedin=ALLBUT,texComment,texCommandNoSpell

syn region texMathZoneEquationC
  \ start='\\begin{\(equation\|equation\*\)}'
  \ end='\\end{\(equation\|equation\*\)}'
  \ keepend
  \ contains=@texMathZoneGroup
  \ containedin=ALLBUT,texComment,texCommandNoSpell

" Extend the built-in reference rules; clearing texRefZone removes citation
" handling (and its exclusion of citation keys from spellchecking).
syn region texRefZone
  \ matchgroup=texStatement
  \ start=/\\\(cref\|labelcref\|namecref\|pagecref\|label\){/
  \ end=/}\|%stopzone\>/
  \ keepend
  \ contains=@texRefGroup
  \ containedin=ALLBUT,texComment,texCommandNoSpell

" Exclude command names (including custom macros) from spellchecking, also
" in comments. Preserve parent highlighting and keep prose arguments checked.
syn match texCommandNoSpell /\\[a-zA-Z@]\+/
  \ contained containedin=texStatement,texComment transparent contains=@NoSpell

" Ignore reference keys in comments while preserving their comment color.
" Reuse this wrapper so math/reference regions cannot start inside it.
syn match texCommandNoSpell /\\\%([cC]ref\|labelcref\|name[cC]ref\|pagecref\|label\|v\?ref\|eqref\|[cC]\?pageref\)\>\*\?\s*{[^}]*}/
  \ contained containedin=texComment transparent contains=@NoSpell

" Math styling/operator arguments contain symbols; leave prose macros checked.
" Reuse the exclusion wrapper and balance nested braces within the comment.
syn region texCommandNoSpell matchgroup=texComment
  \ start=/\\\%(math\%(rm\|bf\|it\|sf\|tt\|cal\|bb\|frak\|normal\|scr\)\|boldsymbol\|bm\|operatorname\)\>\*\?\s*{/
  \ skip=/\\\\\|\\[{}]/ end=/}/
  \ contained containedin=texComment transparent oneline
  \ contains=texCommandNoSpell,@NoSpell
syn region texCommandNoSpell matchgroup=texComment
  \ start=/\%(\%(^\|[^\\]\)\%(\\\\\)*\)\@<={/ skip=/\\\\\|\\[{}]/ end=/}/
  \ contained transparent oneline contains=texCommandNoSpell,@NoSpell

" Parse citations in comments before the generic command exclusion above.
" Use Vim's citation argument rules to exclude keys, including multiple keys.
" Keep the command itself highlighted like other TeX commands.
syn match texRefZone /\\cite\%([tp]\)\?\>\*\?/
  \ containedin=texComment
  \ contains=texStatement
  \ nextgroup=texRefOption,texCite skipwhite skipnl
