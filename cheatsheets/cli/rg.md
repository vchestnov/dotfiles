# rg

Fast recursive search. In this dotfiles repo `rg` is aliased to `rg --smart-case`.

## Everyday search

```bash
rg 'pattern'
rg -n -C 3 'pattern'                 # line numbers and context
rg -l 'pattern'                       # matching file names only
rg -i 'pattern'                       # case-insensitive
rg -F 'literal.string'                # literal, not a regular expression
rg -e 'foo' -e 'bar' path/            # either pattern
rg -v 'pattern' file                  # non-matching lines
```

## Narrow the search

```bash
rg 'pattern' --glob '*.py'
rg 'pattern' -g '!vendor/**' -g '!*.min.js'
rg 'pattern' --type-add 'web:*.{html,css,js}' -t web
rg 'pattern' --hidden -g '!.git/**'
rg 'pattern' --no-ignore              # include ignored files
rg -uu 'pattern'                      # include hidden and ignored files
```

## Files and replacements

```bash
rg --files
rg --files -g '*.md'
rg -o 'https?://[^[:space:]]+'         # print matches only
rg -c 'pattern'                        # count matches per file
rg -U 'start\nend'                     # allow a pattern across lines
rg -l0 'old' | xargs -0 sed -i.bak 's/old/new/g'
```

## Review results

```bash
rg -H --pretty 'pattern'
rg --color=always -n -C 3 'pattern' | less -R
rg --color=always -n 'pattern' | fzf --ansi
```

## With fd

```bash
fd -t f -e m -e wl -x rg -H --pretty -e 'pattern' {}
fd -t f --extension sh ../ -x rg -n 'date' {}
```
