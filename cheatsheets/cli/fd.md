# fd

Fast file finder. In this dotfiles repo `fd` is aliased to `fd --hidden`.

## Everyday finding

```bash
fd pattern
fd -t f pattern                       # files
fd -t d pattern                       # directories
fd -e pdf                             # extension
fd -g '*.tex'                         # glob rather than regex
fd -a -t f pattern                    # print absolute paths
fd -p 'Scratch/Singular'              # full path match
```

## Scope and exclusions

```bash
fd -d 1 -t f                          # at most one level deep
fd --exact-depth 3 -t d
fd pattern path/to/search/
fd -HI pattern                         # include hidden and ignored paths
fd -E .git -E node_modules pattern
```

## Act on matches

```bash
fd -t f -e pdf -x cp {} archive/       # one command per match
fd -t f -e jpg -X magick mogrify -resize 50%  # all matches at once
fd -0 -t f -e m | xargs -0 rg -n 'pivot'
fd -t f pattern -x stat --format '%Y %n' {}
```

## Pick a file

```bash
fd -t f | fzf --preview 'bat --style=numbers --color=always {}'
fd -t f -e pdf -x stat --format '%Y %n' {} | sort -n | cut -d' ' -f2- | fzf
```
