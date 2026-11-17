#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
source "$repo_dir/bootstrap/installers/amflow.sh"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
component_incomplete() { printf '%s\n' "$*" >> "$tmp_dir/incomplete"; }
log_error() { printf '%s\n' "$*" >> "$tmp_dir/errors"; }
log_success() { :; }
SCI_PREFIX="$tmp_dir/prefix"
SCI_JOBS=1
BUILD_DIR="$tmp_dir/build"

# Explicit invalid paths must fail rather than silently selecting another kit.
AMFLOW_WSTP_DIR="$tmp_dir/absent"
if detect_amflow_wstp; then fail 'accepted missing WSTP kit'; fi
case "$(uname -m)" in
    x86_64) architecture=Linux-x86-64 ;;
    aarch64) architecture=Linux-ARM64 ;;
    *) architecture="Linux-$(uname -m)" ;;
esac
AMFLOW_WSTP_DIR="$tmp_dir/wolfram/SystemFiles/Links/WSTP/DeveloperKit/$architecture"
mkdir -p "$AMFLOW_WSTP_DIR/CompilerAdditions"
printf '#!/bin/sh\nexit 0\n' > "$AMFLOW_WSTP_DIR/CompilerAdditions/wsprep"
chmod +x "$AMFLOW_WSTP_DIR/CompilerAdditions/wsprep"
[[ $(detect_amflow_wstp) == "$AMFLOW_WSTP_DIR" ]] || fail 'ignored explicit WSTP kit'

# Follow a PATH symlink without starting the Wolfram executable or a licence flow.
expected=$AMFLOW_WSTP_DIR
unset AMFLOW_WSTP_DIR
mkdir -p "$tmp_dir/wolfram/Executables" "$tmp_dir/bin"
printf '#!/bin/sh\nexit 99\n' > "$tmp_dir/wolfram/Executables/math"
chmod +x "$tmp_dir/wolfram/Executables/math"
ln -s "$tmp_dir/wolfram/Executables/math" "$tmp_dir/bin/math"
command() {
    if [[ "$*" == '-v WolframKernel' ]]; then return 1; fi
    builtin command "$@"
}
[[ $(PATH="$tmp_dir/bin:$PATH" detect_amflow_wstp) == "$expected" ]] || fail 'symlinked Wolfram kit not detected'
unset -f command

# Incomplete prerequisites must not modify a checkout or invoke make.
CXX=amflow-test-missing-compiler
build_amflow_solver "$tmp_dir/nonexistent-checkout"
[[ ! -e "$BUILD_DIR" ]] || fail 'missing prerequisite created build files'
grep -q 'amflow-test-missing-compiler' "$tmp_dir/incomplete" || fail 'missing prerequisite not reported'
unset CXX

# Exercise real Git updates, make, and binary replacement with tiny local
# sources. The compiler probe is stubbed so science libraries are not required.
(
    source "$repo_dir/bootstrap/lib.sh"
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    export GIT_AUTHOR_NAME='AMFlow fixture' GIT_AUTHOR_EMAIL=fixture@example.invalid
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
    fixture="$tmp_dir/lifecycle"
    upstream="$fixture/upstream"
    checkout="$fixture/amflow"
    SCI_PREFIX="$fixture/prefix"
    BUILD_DIR="$fixture/build"
    AMFLOW_WSTP_DIR=$expected
    mkdir -p "$fixture/bin" "$upstream/diffeq_solver/"{include,src}
    CXX="$fixture/bin/fixture-cxx"
    cat > "$CXX" <<'COMPILER'
#!/usr/bin/env bash
set -Eeuo pipefail
while (( $# )); do
    case "$1" in
        -o) output=$2; shift 2 ;;
        *) shift ;;
    esac
done
printf '#!/usr/bin/env bash\nexit 0\n' > "$output"
chmod +x "$output"
COMPILER
    printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/bin/mpsolve"
    chmod +x "$CXX" "$fixture/bin/mpsolve"
    export PATH="$fixture/bin:$PATH"
    printf 'header\n' > "$upstream/diffeq_solver/include/fixture.hpp"
    printf 'version 1\n' > "$upstream/diffeq_solver/src/version"
    cat > "$upstream/diffeq_solver/Makefile" <<'MAKE'
.PHONY: desolver link
desolver link:
	test "$(CONFIG_FILE)" = /dev/null
	test -f include/fixture.hpp
	cp src/version "$@"
MAKE
    git init -q --initial-branch=main "$upstream"
    git -C "$upstream" add .
    git -C "$upstream" commit -qm initial

    update_amflow_checkout "$checkout" "$upstream"
    build_amflow_solver "$checkout"
    for target in desolver link; do
        [[ -x "$checkout/diffeq_solver/$target" ]] || fail "$target was not installed executable"
        [[ $(cat "$checkout/diffeq_solver/$target") == 'version 1' ]] || fail "$target has wrong contents"
    done
    [[ -z $(git -C "$checkout" status --porcelain) ]] || fail 'installed binaries made the source dirty'
    [[ ! -e "$checkout/.gitignore" && ! -e "$checkout/diffeq_solver/obj" ]] \
        || fail 'build or ignore configuration leaked into source files'

    exclude_file=$(git -C "$checkout" rev-parse --path-format=absolute --git-path info/exclude)
    printf '\n# User exclude\n/custom-scratch\n' >> "$exclude_file"
    cp "$exclude_file" "$fixture/exclude-before"
    printf 'version 2\n' > "$upstream/diffeq_solver/src/version"
    git -C "$upstream" commit -qam upgrade
    update_amflow_checkout "$checkout" "$upstream"
    [[ $(git -C "$checkout" rev-parse HEAD) == "$(git -C "$upstream" rev-parse HEAD)" ]] \
        || fail 'installed binaries prevented the next upstream update'
    build_amflow_solver "$checkout"
    for target in desolver link; do
        [[ -x "$checkout/diffeq_solver/$target" ]] || fail "$target lost executable mode"
        [[ $(cat "$checkout/diffeq_solver/$target") == 'version 2' ]] || fail "$target was not upgraded"
        backups=("$checkout/diffeq_solver/$target".backup.*)
        [[ ${#backups[@]} == 1 && $(cat "${backups[0]}") == 'version 1' ]] \
            || fail "$target replacement did not preserve the previous executable"
    done
    [[ -z $(git -C "$checkout" status --porcelain) ]] || fail 'binary backups made the source dirty'
    cmp -s "$exclude_file" "$fixture/exclude-before" || fail 'repeat run changed existing Git excludes'

    # Earlier installers left untracked binaries and backups without local
    # excludes. They must be migrated before clone_or_update checks status.
    printf '# User exclude\n/custom-scratch\n' > "$exclude_file"
    printf 'version 3\n' > "$upstream/diffeq_solver/src/version"
    git -C "$upstream" commit -qam next-upgrade
    update_amflow_checkout "$checkout" "$upstream"
    [[ $(git -C "$checkout" rev-parse HEAD) == "$(git -C "$upstream" rev-parse HEAD)" ]] \
        || fail 'older installs were not migrated before checking for dirty sources'
    grep -qxF '/custom-scratch' "$exclude_file" || fail 'migration lost user excludes'

    # Generated results and tracked edits must still block automatic updates.
    previous_head=$(git -C "$checkout" rev-parse HEAD)
    printf 'version 4\n' > "$upstream/diffeq_solver/src/version"
    git -C "$upstream" commit -qam later-upgrade
    mkdir -p "$checkout/examples/calculation"
    printf 'scientific result\n' > "$checkout/examples/calculation/sol"
    update_amflow_checkout "$checkout" "$upstream"
    [[ $(git -C "$checkout" rev-parse HEAD) == "$previous_head" ]] || fail 'untracked results did not block update'
    [[ $(cat "$checkout/examples/calculation/sol") == 'scientific result' ]] || fail 'calculation result was changed'
    mv "$checkout/examples" "$fixture/saved-results"
    printf 'local source edit\n' > "$checkout/diffeq_solver/include/fixture.hpp"
    update_amflow_checkout "$checkout" "$upstream"
    [[ $(git -C "$checkout" rev-parse HEAD) == "$previous_head" ]] || fail 'tracked edits did not block update'
    [[ $(cat "$checkout/diffeq_solver/include/fixture.hpp") == 'local source edit' ]] || fail 'source edit was changed'
)

printf 'AMFlow installer checks passed.\n'
