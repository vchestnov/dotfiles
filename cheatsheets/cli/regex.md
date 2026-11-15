# regex

Practical regular expressions for the CLI tools in this directory. Quote patterns with single quotes so Bash does not interpret special characters.

## Everyday patterns

```text
^TODO\b                         line starts with TODO
error|warning                   either word
\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b  ISO date
\b[[:digit:]]{1,3}(\.[[:digit:]]{1,3}){3}\b  IPv4-shaped address
https?://[^[:space:]]+          URL
^[[:space:]]*$                  blank or whitespace-only line
^[[:space:]]*#                  comment line with optional indentation
[^[:space:]]+$                  final non-whitespace token on a line
```

## `rg`: search code and text

```bash
rg -n '^TODO\b'
rg -n -i 'fix(me)?|bug'
rg -o '\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b'
rg -n 'function[[:space:]]+[[:alnum:]_]+'
rg -n '^\s*import\s+.+from\s+["\x27]' --glob '*.{js,ts}'
rg -P '(?<=version=)[0-9.]+'            # lookbehind needs PCRE2
```

`rg` uses Rust regex by default: it supports character classes, groups, alternation, and repetition, but not look-around or backreferences. Add `-P` for PCRE2 when needed; prefer the default engine for ordinary searches.

## `fd`: find files by name or path

```bash
fd '\.(md|txt)$'
fd '^README(\.md)?$'
fd -p '(^|/)src/.*\.(rs|py)$'            # match the full path
fd -g '*.{jpg,jpeg,png}'                 # glob syntax, often simpler for extensions
fd -E '.git' '^[[:alnum:]_-]+\.sh$'
```

`fd PATTERN` uses a regular expression against a path component; use `-p` for the whole path. `fd -g GLOB` switches to shell-style glob syntax.

## `sed`: select or rewrite lines

```bash
sed -n -E '/^[[:space:]]*#/p' file       # print comment lines
sed -E '/^[[:space:]]*$/d' file          # remove blank lines
sed -E 's/[[:space:]]+$//' file           # trim trailing whitespace
sed -E 's/^([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2})$/\3\/\2\/\1/' file
sed -E 's/(https?):\/\/([^/]+).*/\2/' file # extract URL host
```

Use `sed -E` for extended regular expressions: `+`, `?`, `|`, `()`, and `{n,m}` work without backslashes. In default basic regex mode, escape those operators (`\+`, `\?`, `\|`, `\(`, `\{`).

## `awk`: filter and extract fields

```bash
awk '/^[[:space:]]*#/ {next} NF' file    # skip comments and blank lines
awk '$1 ~ /^[[:digit:]]+$/ {print $1}' file
awk 'match($0, /https?:\/\/[^[:space:]\/]+/) {print substr($0, RSTART, RLENGTH)}' file # scheme and host
awk -F: '$1 ~ /^(root|www-data)$/ {print $1, $7}' /etc/passwd
```

`awk` uses extended regular expressions. Use `~` for a match and `!~` for no match. Capture groups match but do not create directly addressable captures; use `match()` with `RSTART` and `RLENGTH` to extract the whole match.

## `find`: match complete paths

```bash
find . -regextype posix-extended -regex '.*\.(jpg|jpeg|png)'
find . -regextype posix-extended -regex '.*/src/[^/]+\.py'
find . -type f -name '*.md'              # use `-name` when a glob is enough
```

`find -regex` normally matches the entire path, including `./`, and the default regex dialect varies by platform. On GNU `find`, use `-regextype posix-extended` when you want predictable ERE syntax.

## Building blocks

```text
.       any character (except newline)
^ / $   start / end of line
* + ?   zero-or-more / one-or-more / optional
{n,m}   repetition range
[]      one character from a class or range
[^abc]  one character except a, b, or c
()      group
|       alternative
\b      word boundary (`rg`; portability varies elsewhere)
```

Prefer POSIX classes inside `[]` for portable CLI patterns: `[[:digit:]]`, `[[:alpha:]]`, `[[:alnum:]]`, `[[:space:]]`, and `[[:upper:]]`.
