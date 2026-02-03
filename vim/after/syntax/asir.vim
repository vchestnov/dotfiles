" asir.vim - Vim syntax file for Risa/Asir (.rr)
"
" This file lives in: after/syntax/asir.vim
" so it can extend whatever the main ftplugin/syntax already does.

if exists("b:current_syntax")
  finish
endif

" Use C as a baseline: strings, numbers, operators, /* */ comments
runtime! syntax/c.vim
unlet! b:current_syntax

" ---------------------------------------------------------------------
" Core Asir-ish keywords and declarations seen in real .rr code
" ---------------------------------------------------------------------
" syn keyword asirStatement return if else for while break continue
syn keyword asirDecl      def localf static extern module endmodule import load
syn keyword asirBoolean   true false

" hi def link asirStatement Statement
hi def link asirDecl      Keyword
hi def link asirBoolean   Boolean

" ---------------------------------------------------------------------
" Preprocessor-ish directives (single line!)
" (they are not C-preprocessor in the exact sense, but highlight similarly)
" ---------------------------------------------------------------------
syn match asirPreproc /^\s*#\s*\%(define\|undef\|ifdef\|ifndef\|if\|elif\|else\|endif\)\>.*$/
hi def link asirPreproc PreProc

" ---------------------------------------------------------------------
" Statement terminator: $
" ---------------------------------------------------------------------
" syn match asirTerminator /\$/ containedin=ALL
syn match asirTerminator /\$/ containedin=ALLBUT,cComment,cCommentL,cString,cCppString,cCharacter,cCppCharacter
hi def link asirTerminator Delimiter

" ---------------------------------------------------------------------
" Module name:   module mt_gkz$
" Highlight "mt_gkz" specially.
" ---------------------------------------------------------------------
syn match asirModuleDecl /^\s*module\s\+\zs[A-Za-z_][A-Za-z0-9_]*\ze\$\s*$/ containedin=asirPreproc
hi def link asirModuleDecl Namespace

" ---------------------------------------------------------------------
" Declarations: localf foo$  / static Check_BF$ / extern Check_BF$
" Highlight the declared symbol name.
" ---------------------------------------------------------------------
syn match asirLocalf /^\s*localf\s\+\zs[A-Za-z_][A-Za-z0-9_]*\ze\$\s*$/
hi def link asirLocalf Function

syn match asirStatic /^\s*static\s\+\zs[A-Za-z_][A-Za-z0-9_]*\ze\$\s*/
hi def link asirStatic Identifier

syn match asirExtern /^\s*extern\s\+\zs[A-Za-z_][A-Za-z0-9_]*\ze\$\s*/
hi def link asirExtern Identifier

" ---------------------------------------------------------------------
" Function definitions: def name(...) { ... }
" Highlight the function name.
" ---------------------------------------------------------------------
syn match asirDefFunc /^\s*def\s\+\zs[A-Za-z_][A-Za-z0-9_]*\ze\s*(/
hi def link asirDefFunc Function

" ---------------------------------------------------------------------
" Options syntax:   ... | partial=1
" Also highlight getopt(foo) calls
" ---------------------------------------------------------------------
" syn match asirOptBar /|/ containedin=ALL
syn match asirOptBar /|/ containedin=ALLBUT,cComment,cCommentL,cString,cCppString,cCharacter,cCppCharacter
hi def link asirOptBar Operator

syn match asirOptName /\<\h\w*\ze\s*=/ containedin=ALLBUT,cComment,cCommentL,cString,cCppString,cCharacter,cCppCharacter
hi def link asirOptName Identifier

" syn match asirGetopt /\<getopt\>\s*(/ containedin=ALL
syn match asirGetopt /\<getopt\>\ze\s*(/ containedin=ALLBUT,cComment,cCommentL,cString,cCppString,cCharacter,cCppCharacter
hi def link asirGetopt Function

" ---------------------------------------------------------------------
" Dotted namespaces and calls:
"   yang.buchberger(...)
"   sm1.gkz(...)
" Highlight prefix as Namespace and member as Function when it's a call.
" ---------------------------------------------------------------------
syn match asirNamespace /\<[a-z][a-z0-9_]*\ze\./
hi def link asirNamespace Namespace

syn match asirDotCall /\<[a-z][a-z0-9_]*\.\zs[a-z][a-z0-9_]*\ze\s*(/ contains=asirNamespace
hi def link asirDotCall Function

" Optional: dotted constant-ish access (rare). Uncomment if you want it.
" syn match asirDotField /\<[a-z][a-z0-9_]*\.\zs[A-Za-z_][A-Za-z0-9_]*\>/ contains=asirNamespace
" hi def link asirDotField Identifier

" ---------------------------------------------------------------------
" User variables heuristic:
" - ALLCAPS / mixed caps (Check_BF, Facet_poly, GKZ, Id, Shift, Beta, ...)
" This will inevitably also match some things you might not want, but
" in practice it's very helpful in Asir codebases.
" ---------------------------------------------------------------------
" syn match asirConst /\<[A-Z][A-Z0-9_]\{2,}\>/
" hi def link asirConst Constant

syn match asirUserVar /\<[A-Z][A-Za-z0-9_]*\>/ containedin=ALLBUT,cComment,cCommentL,cString,cCppString,cCharacter,cCppCharacter
hi def link asirUserVar Identifier

" " Prefer Const over UserVar if both match
" syn cluster asirCaps contains=asirConst,asirUserVar

" ---------------------------------------------------------------------
" Asir-specific operators / delimiters often seen in contrib:
"  - << ... >>  (common for differential operator vectors etc.)
" ---------------------------------------------------------------------
" syn match asirAngleDelim /<<\|>>/ containedin=ALL
syn match asirAngleDelim /<<\|>>/ containedin=ALLBUT,cComment,cCommentL,cString,cCppString,cCharacter,cCppCharacter
hi def link asirAngleDelim Delimiter

" ---------------------------------------------------------------------
" Highlight .rr paths inside string literals
" (works with the C string groups we inherited)
" ---------------------------------------------------------------------
syn match asirRRPath /"\zs[^"]\+\.rr\ze"/ containedin=cString,cCppString,cCharacter,cCppCharacter
hi def link asirRRPath String

let b:current_syntax = "asir"
