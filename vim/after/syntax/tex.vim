" Make align a full math zone (like equation)
syn region texMathZoneC start='\\begin{\(align\|align\*\)}' end='\\end{\(align\|align\*\)}' keepend contains=@texMathZoneGroup
" syn region texRefZone matchgroup=texStatement start=/\\cref{/ end=/}\|%stopzone\>/  contains=@texRefGroup
syn region texRefZone matchgroup=texStatement start=/\\\(cref\|labelcref\|namecref\|pagecref\){/ end=/}\|%stopzone\>/ contains=@texRefGroup
