# bash

Shell loops, quoting, and small scripts.

## Reliable scripts

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

trap 'printf "failed: %s (line %s)\n" "$BASH_COMMAND" "$LINENO" >&2' ERR
```

## Variables, arguments, and quoting

```bash
printf '%s\n' "$variable"              # always quote paths and text
command -- "$file"                     # end option parsing for an untrusted name
"${var:-default}"                     # default when unset or empty
"${var:?missing var}"                 # fail with a useful message
"${file%.zip}"                        # remove suffix
"${file%.jpg}.png"                    # change suffix
```

## Files and loops

```bash
for file in ./*.zip; do
  [[ -e $file ]] || continue            # glob matched nothing
  unzip "$file" -d "${file%.zip}"
done

while IFS= read -r -d '' file; do
  printf '%s\n' "$file"
done < <(find . -type f -print0)
```

## Useful small patterns

```bash
for arg in "$@"; do printf '<%s>\n' "$arg"; done
mapfile -t lines < <(command-that-prints-lines)
printf '%s\n' "${lines[@]}"
comm -12 <(cmd_a | sort) <(cmd_b | sort)
```

## Notes

Use arrays for lists: `args=(--flag "two words")` then `command "${args[@]}"`. Avoid parsing `ls` output and avoid `for x in $(command)`; both split spaces and glob characters unexpectedly.
