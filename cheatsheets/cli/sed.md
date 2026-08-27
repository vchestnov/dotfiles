# sed

Stream editor for substitutions, selection, and quick pipeline cleanup.

## Everyday editing

```bash
sed 's/old/new/' file                  # first match on each line
sed 's/old/new/g' file                 # every match on each line
sed -E 's/[[:space:]]+/ /g' file        # collapse whitespace
sed '/^$/d' file                        # remove blank lines
sed -n '1,20p' file                     # lines 1 through 20
sed -n '/start/,/end/p' file             # inclusive range
```

## Substitution patterns

```bash
sed -E 's/([0-9]+)-([0-9]+)/\2\/\1/' file
sed 's|/old/path|/new/path|g' file
sed 's/^/prefix: /; s/$/;/' file
sed -n 's/^commit //p' file
sed -E 's/[[:space:]]+$//' file          # trim trailing whitespace
```

## In-place edit safely

```bash
sed -i.bak -e 's/old/new/g' file         # GNU sed; macOS: sed -i .bak -e ...
sed -i.bak -e '/pattern/d' file
rg -l0 'old' | xargs -0 -r sed -i.bak 's/old/new/g'
```

## Notes

Use single quotes for sed programs unless the shell must expand variables. Use a delimiter like `|` for paths. Review output before adding `-i`; the backup suffix gives you a rollback file.
