# find

Portable file traversal. Prefer `fd` for interactive use; use `find` for POSIX-ish scripts and complex predicates.

## Everyday finding

```bash
find . -name '*.zip'
find . -type f -iname '*viro*'         # case-insensitive name
find . -type f -maxdepth 1
find . -type f \( -name '*.jpg' -o -name '*.png' \)
find . -type f -mtime -7               # modified in the last seven days
find . -type f -size +100M
```

## Review then batch operations

```bash
find . -type f -name '*.tmp' -print
find . -type f -name '*.tmp' -delete    # run only after reviewing the command above
find . -type f -name '*.log' -print0 | xargs -0 -r gzip
find . -type f -name '*.zip' -exec sh -c 'unzip -d "${1%.*}" "$1"' _ {} \;
find . -type f -name '*.epub' -exec ebook-convert {} {}.pdf \;
```

## Predicates and pruning

```bash
find . -type f -not -path './.git/*'
find . -path './.git' -prune -o -type f -print
find . -empty                         # empty files and directories
find . -type f -perm -111             # executable files
find . -type d -exec chmod 755 {} +
find . -type f -exec chmod 644 {} +
```

## Regex

```bash
find . -regextype sed -regex '.*/[[:digit:]]\{,2\}\.jpg'
```
