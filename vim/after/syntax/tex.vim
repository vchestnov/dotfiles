" Make align a full math zone (like equation)
syn region texMathZoneC start='\\begin{\(align\|align\*\)}' end='\\end{\(align\|align\*\)}' keepend contains=@texMathZoneGroup
