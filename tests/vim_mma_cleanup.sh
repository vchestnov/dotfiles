#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
vim_bin=$(command -v "${VIM_BIN:-vim}")

# Exercise helper path quoting and the ~/.vim symlink used on real hosts.
checkout="$tmp_dir/checkout with 'quotes"
mkdir -p "$checkout/vim/after/ftplugin" "$checkout/scripts/lib" \
    "$tmp_dir/home" "$tmp_dir/empty-bin" "$tmp_dir/failing-bin"
cp "$repo_dir/vim/after/ftplugin/mma.vim" "$checkout/vim/after/ftplugin/"
cp "$repo_dir/scripts/lib/mathematica-format.py" "$checkout/scripts/lib/"
ln -s "$checkout/vim" "$tmp_dir/home/.vim"

cat > "$tmp_dir/input.wl" <<'EOF'
(* ::Input::Initialization:: *)
(* ::Section::Initialization:: *)
(*comment   *)
f [ x_ ,y_ ]:=Module[ { a=1,b=- 2 },
<|"λ"->x+y,"text"->"a+b, c->d"|>;
(* outer (* inner *) comment
  x+y, z->w
*)
{a,b,- 3,+ 4,x[[1;;2]],1.2*^3}//foo
]
EOF

cat > "$tmp_dir/expected.wl" <<'EOF'
(* ::Section:: *)
(* comment *)
f[x_, y_] := Module[{a = 1, b = -2},
    <|"λ" -> x + y, "text" -> "a+b, c->d"|>;
    (* outer (* inner *) comment
    x+y, z->w
    *)
    {a, b, -3, +4, x[[1;;2]], 1.2*^3} // foo
]
EOF

cat > "$tmp_dir/failing-bin/python3" <<'EOF'
#!/bin/sh
printf 'fixture formatter failure\n' >&2
exit 1
EOF
chmod 0755 "$tmp_dir/failing-bin/python3"

cat > "$tmp_dir/check.vim" <<'EOF'
set encoding=utf-8
execute 'edit ' . fnameescape($MMA_TEST_DIR . '/input.wl')
execute 'source ' . fnameescape($MMA_TEST_DIR . '/home/.vim/after/ftplugin/mma.vim')
let original = getline(1, '$')
call cursor(4, 5)
let view = winsaveview()
MathematicaCleanup
call assert_equal(readfile($MMA_TEST_DIR . '/expected.wl'), getline(1, '$'))
call assert_equal(view.lnum, line('.'))
call assert_equal(view.col, col('.') - 1)
call assert_equal([1, 4, 4, 4], [&l:expandtab, &l:shiftwidth, &l:softtabstop, &l:tabstop])
undo
call assert_equal(original, getline(1, '$'), 'cleanup should undo as one change')

for alias in ['MathematicaClean', 'MmaClean', 'MmaCleanup']
    execute alias
    call assert_equal(readfile($MMA_TEST_DIR . '/expected.wl'), getline(1, '$'))
endfor

" An all-marker buffer must become a valid, empty Vim buffer.
%delete _
call setline(1, '(* ::Input::Initialization:: *)')
MathematicaCleanup
call assert_equal([''], getline(1, '$'))

" Missing Python and helper failures must leave text and options untouched.
let saved_path = $PATH
for failure in ['empty-bin', 'failing-bin']
    execute 'edit! ' . fnameescape($MMA_TEST_DIR . '/input.wl')
    setlocal noexpandtab shiftwidth=8 softtabstop=0 tabstop=8
    let $PATH = $MMA_TEST_DIR . '/' . failure
    try
        MathematicaCleanup
        call assert_report('cleanup accepted ' . failure)
    catch
        call assert_match(failure ==# 'empty-bin' ? 'needs python3' : 'fixture formatter failure', v:exception)
    endtry
    let $PATH = saved_path
    call assert_equal(original, getline(1, '$'))
    call assert_equal([0, 8, 0, 8], [&l:expandtab, &l:shiftwidth, &l:softtabstop, &l:tabstop])
endfor

if !empty(v:errors)
    call writefile(v:errors, $MMA_TEST_DIR . '/errors')
    cquit 1
endif
qa!
EOF

if ! MMA_TEST_DIR="$tmp_dir" "$vim_bin" -Nu NONE -n -i NONE -X -es \
    -V1"$tmp_dir/vim.log" -S "$tmp_dir/check.vim" > "$tmp_dir/output" 2>&1; then
    if [[ -f "$tmp_dir/errors" ]]; then cat "$tmp_dir/errors" >&2; fi
    tail -n 30 "$tmp_dir/vim.log" >&2
    exit 1
fi

printf 'Vim Mathematica cleanup checks passed\n'
