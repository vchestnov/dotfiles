" asir.vim - Vim syntax file for Risa/Asir

if exists("b:current_syntax")
  finish
endif

" Include C syntax as a base
runtime! syntax/c.vim
unlet! b:current_syntax

" Add Asir-specific keywords
syn keyword asirKeyword newalg defpoly alg algv simpalg algptorat rattoalgp
syn keyword asirFunction idiv irem fac igcd ilcm inv prime lprime random
syn keyword asirStatement return if else for while break continue def
syn keyword asirType int real string list array struct

" Highlight Asir-specific functions and statements
hi def link asirKeyword Keyword
hi def link asirFunction Function
hi def link asirStatement Statement
hi def link asirType Type

let b:current_syntax = "asir"
