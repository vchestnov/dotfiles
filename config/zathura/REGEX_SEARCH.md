# Vim regexp searches in Zathura

Press `/`, enter a Vim expression in the dmenu prompt, and press Enter. Do not
include enclosing slashes. Matches are highlighted in the PDF and the selected
match is centered in the viewer.

| Keys | Action |
| --- | --- |
| `/` | New forward regexp search |
| `?` | New backward regexp search |
| `n` | Next match in the search's original direction, wrapping at the end |
| `N` | Previous match, wrapping at the end |
| `g/`, `g?` | Zathura's original literal search bar |
| `gn`, `gN` | Navigate native literal search results forward/backward |

Escape cancels the prompt. Submitting an empty prompt reuses this window's last
expression. A new search starts on the current page (at its first matching item
for `/`, or its last for `?`), then continues through the document. `n` and `N`
continue from the selected match even if you scroll manually.

Examples:

| Expression | Finds |
| --- | --- |
| `\<BP\>` | The whole word BP, excluding ABP, BPs and BP_1 |
| `\c\<bp\>` | BP, bp, Bp, etc. |
| `^BP` | BP at the beginning of an extracted text line |
| `First\_s\+line` | First followed by whitespace, including a line break, then line |
| `\Vliteral.text` | Literal text, including the dot |

For either collaborator's initials as a whole word, use either of these
equivalent expressions (normal Vim syntax, then very magic syntax):

```vim
\<\(BP\|GB\)\>
\v<(BP|GB)>
```

The matcher uses Vim itself, with a clean configuration, UTF-8, case-sensitive
matching, `magic`, and the default word characters (letters, digits and
underscore). `\c`, `\C`, `\v`, `\V`, lookarounds, `\zs`, and `\ze` use Vim's
syntax. Text is searched page by page; matches cannot span pages. PDF extraction
determines spaces, line breaks and reading order. Scans need a searchable text
layer; annotation popups are not page text. Expressions matching only a position,
such as `^`, have no visible text to highlight.

The helper is [scripts/zathura-regex-search](../../scripts/zathura-regex-search),
with [the Vim matcher](../../scripts/lib/zathura-regex.vim). It requires system
Python with PyGObject and Poppler (`python3-gi`, `gir1.2-poppler-0.18` on Ubuntu),
Vim, dmenu and a session D-Bus. Searches from the viewer shortcuts are silent,
including failures: no dialogs or terminal messages. Direct command-line searches
using `--pattern` retain error diagnostics on stderr. Failed searches preserve
the current view and the last successful search.
Patterns are passed to Vim as JSON data. No expression is evaluated as shell or
Ex commands. Per-window results live in `$XDG_RUNTIME_DIR/zathura-regex`, falling
back to `$XDG_CACHE_HOME/zathura-regex` or `~/.cache/zathura-regex`. A PDF rebuild
invalidates the stored match positions on the next `n` or `N`.

## Zathura 0.5.14 highlighting correction

The installed 0.5.14 release frees rectangle lists after transferring them to
page widgets in its D-Bus `HighlightRects` handler. Repeated highlighting then
uses freed memory and crashes. [highlight-ownership.patch](highlight-ownership.patch)
corrects that ownership, as in the
[upstream implementation](https://github.com/pwmt/zathura/blob/develop/zathura/dbus-interface.c),
and marks the build `0.5.14+highlightfix`. The helper refuses unmarked 0.5.x
windows so that reopening the viewer is safe after installation.

The corrected executable is installed as `~/.local/bin/zathura`. Close and reopen
existing Zathura windows once, using that executable. The configuration and
shortcuts then load automatically on subsequent launches. Double-click links,
`f` link hints and SyncTeX keep their existing bindings.

To reproduce the build on this machine, with its installed development libraries
and matching PDF plugins, run from the dotfiles checkout:

```sh
repo_dir="$PWD"
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/bootstrap"
build_root=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/bootstrap/zathura-regex.XXXXXX")
curl -fL https://pwmt.org/projects/zathura/download/zathura-0.5.14.tar.xz \
  -o "$build_root/zathura.tar.xz"
printf '647aca4d494315905d236504576e35b7568a4d702e56aa4590295a9f6a7259bd  %s\n' \
  "$build_root/zathura.tar.xz" | sha256sum -c -
mkdir "$build_root/source"
tar -xf "$build_root/zathura.tar.xz" -C "$build_root/source" --strip-components=1
patch -d "$build_root/source" -p1 -i "$repo_dir/config/zathura/highlight-ownership.patch"
plugin_dir=$(pkg-config --variable=plugindir zathura)
meson setup "$build_root/build" "$build_root/source" --prefix="$HOME/.local" \
  --libdir="${plugin_dir%/zathura}" --buildtype=release \
  -Dsynctex=enabled -Dmanpages=disabled -Dtests=disabled -Dconvert-icon=disabled
ninja -C "$build_root/build" zathura
install -Dm755 "$build_root/build/zathura" "$HOME/.local/bin/zathura"
```

This installs only the corrected executable and reuses the existing plugins. It
does not change the system Zathura installation or plugin ABI. After installation,
`~/.local/bin/zathura --version` should report `0.5.14+highlightfix`.
