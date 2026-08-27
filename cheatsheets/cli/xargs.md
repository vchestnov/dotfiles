# xargs

Build command lines from stdin.

## Everyday use

```bash
printf '%s\n' file1 file2 | xargs ls -d --color=auto
rg -l0 'pattern' | xargs -0 -r sed -i.bak 's/old/new/g'
fd -0 -t f -e jpg | xargs -0 -r -n 1 file
cmd | xargs -n 1 command               # at most one input per invocation
cmd | xargs -P 4 -n 1 command          # four jobs in parallel
```

## Arbitrary filenames

```bash
find . -type f -print0 | xargs -0 -r rg 'pattern'
find . -type f -name '*.log' -print0 | xargs -0 -r rm -v  # delete only after a dry run
```

## Place an argument anywhere

```bash
cmd | xargs -I {} cp {} target/
cmd | xargs -I {} git show {}
printf '%s\n' one two | xargs -I {} sh -c 'printf "[%s]\\n" "{}"'
```

## Notes

Prefer `-0` with producers such as `find -print0`, `rg -0`, and `fd -0`; it handles spaces, quotes, and newlines safely. Use `-r` (GNU `xargs`) to avoid running a command with no input. `-I {}` implies one input per command, so use it only when replacement is needed away from the end.
