#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
export NVM_DIR="$tmp_dir/nvm with spaces" NVM_TEST_REPO="$repo_dir"
export XDG_CONFIG_HOME="$tmp_dir/config"
mkdir -p "$NVM_DIR/alias/lts" "$XDG_CONFIG_HOME/nvm"
for version in v24.15.0 v26.13.1; do
    mkdir -p "$NVM_DIR/versions/node/$version/bin"
    printf '#!/usr/bin/env bash\nprintf "fixture node\\n"\n' > "$NVM_DIR/versions/node/$version/bin/node"
    chmod +x "$NVM_DIR/versions/node/$version/bin/node"
done
cat > "$NVM_DIR/nvm.sh" <<'EOF'
[[ -z "${NPM_CONFIG_PREFIX:-}${npm_config_prefix:-}" ]] || { printf 'unexpected npm prefix while loading nvm\n' >&2; return 1; }
printf '%s\n' "${1:-fallback}" >> "$NVM_TEST_LOG"
nvm() { printf 'fixture nvm\n'; }
if [[ "${1:-}" != --no-use ]]; then
    export NVM_BIN="$NVM_DIR/versions/node/v26.13.1/bin"
    export NVM_INC="$NVM_DIR/versions/node/v26.13.1/include/node"
    export MANPATH="$NVM_DIR/versions/node/v26.13.1/share/man:${MANPATH:-}"
    export PATH="$NVM_BIN:$PATH"
fi
EOF
printf 'source "$NVM_DIR/nvm.sh"\n' > "$XDG_CONFIG_HOME/nvm/env.sh"
cat > "$tmp_dir/check.bash" <<'EOF'
set -Eeuo pipefail
source "$NVM_TEST_REPO/config/nvm/shell.bash"
[[ "$(command -v node)" == "$NVM_TEST_EXPECT/bin/node" ]]
[[ "$NVM_BIN" == "$NVM_TEST_EXPECT/bin" && "$NVM_INC" == "$NVM_TEST_EXPECT/include/node" ]]
[[ "$MANPATH" == "$NVM_TEST_EXPECT/share/man:"* ]]
node >/dev/null
nvm >/dev/null
previous_path=$PATH
source "$NVM_TEST_REPO/config/nvm/shell.bash"
[[ "$PATH" == "$previous_path" ]]
[[ "$(awk '$0 == "fallback" { n++ } END { print n+0 }' "$NVM_TEST_LOG")" == "$NVM_TEST_FALLBACK" ]]
[[ "$(head -n 1 "$NVM_TEST_LOG")" == --no-use ]]
EOF

run_case() {
    local name=$1 version=$2 fallback=$3
    NVM_TEST_LOG="$tmp_dir/$name.log" NVM_TEST_EXPECT="$NVM_DIR/versions/node/$version" \
        NVM_TEST_FALLBACK="$fallback" bash "$tmp_dir/check.bash" \
        || { printf 'FAIL: Node activation case %s\n' "$name" >&2; return 1; }
}
printf 'v26.13.1\n' > "$NVM_DIR/alias/default"
run_case exact v26.13.1 0
printf 'lts/*\n' > "$NVM_DIR/alias/default"
printf 'lts/lithium\n' > "$NVM_DIR/alias/lts/*"
printf 'v26.13.1\n' > "$NVM_DIR/alias/lts/lithium"
run_case lts v26.13.1 0
PATH="$NVM_DIR/versions/node/v24.15.0/bin:$PATH" run_case inherited v24.15.0 0
printf 'project\n' > "$NVM_DIR/alias/default"
printf '24.15.0 # selected version\n' > "$NVM_DIR/alias/project"
run_case custom v24.15.0 0
printf '26\n' > "$NVM_DIR/alias/default"
run_case partial v26.13.1 1
printf 'cycle\n' > "$NVM_DIR/alias/default"
printf 'default\n' > "$NVM_DIR/alias/cycle"
run_case cycle v26.13.1 1

# System Node must supply the same writable prefix to npm launched by Codex.
HOME="$tmp_dir/system home" XDG_CONFIG_HOME="$tmp_dir/system config" \
XDG_DATA_HOME="$tmp_dir/system data" NVM_DIR='' bash <<'EOF'
set -Eeuo pipefail
unset NPM_CONFIG_PREFIX npm_config_prefix DOTFILES_NPM_FALLBACK_PREFIX
source "$NVM_TEST_REPO/config/nvm/shell.bash"
[[ "$NPM_CONFIG_PREFIX" == "$HOME/.local" ]]
bash -c '[[ "$NPM_CONFIG_PREFIX" == "$HOME/.local" ]]'
if command -v npm >/dev/null; then
    [[ "$(npm config get prefix)" == "$HOME/.local" ]]
fi
source "$NVM_TEST_REPO/config/nvm/shell.bash"
[[ "$NPM_CONFIG_PREFIX" == "$HOME/.local" ]]
export NPM_CONFIG_PREFIX="$HOME/custom prefix"
source "$NVM_TEST_REPO/config/nvm/shell.bash"
[[ "$NPM_CONFIG_PREFIX" == "$HOME/custom prefix" ]]
unset NPM_CONFIG_PREFIX
export npm_config_prefix="$HOME/lowercase prefix"
source "$NVM_TEST_REPO/config/nvm/shell.bash"
[[ "$npm_config_prefix" == "$HOME/lowercase prefix" && ! ${NPM_CONFIG_PREFIX+set} ]]
EOF

# Loading nvm in a child of a fallback shell must remove the inherited prefix.
printf 'v26.13.1\n' > "$NVM_DIR/alias/default"
NPM_CONFIG_PREFIX="$HOME/.local" DOTFILES_NPM_FALLBACK_PREFIX="$HOME/.local" \
    run_case inherited-prefix v26.13.1 0

# A standard nvm installation works even before bootstrap writes env.sh.
mv "$XDG_CONFIG_HOME/nvm/env.sh" "$XDG_CONFIG_HOME/nvm/env.saved"
run_case without-env v26.13.1 0

# Installing nvm from a fallback shell must not carry its prefix into nvm/npm.
HOME="$tmp_dir/bootstrap home" XDG_CONFIG_HOME="$tmp_dir/bootstrap config" \
XDG_DATA_HOME="$tmp_dir/bootstrap data" NVM_DIR="$tmp_dir/bootstrap nvm" \
NVM_VERSION=fixture bash <<'EOF'
set -Eeuo pipefail
source "$NVM_TEST_REPO/bootstrap/installers/node.sh"
log_info() { :; }
log_success() { :; }
log_warning() { printf '%s\n' "$*" >&2; }
write_generated_file() { cat > "$1"; }
clone_or_update() {
    mkdir -p "$2"
    cat > "$2/nvm.sh" <<'NVM'
[[ ! ${NPM_CONFIG_PREFIX+set} ]] || return 1
nvm() { :; }
NVM
}
node() { printf 'fixture node\n'; }
npm() {
    [[ ! ${NPM_CONFIG_PREFIX+set} ]]
    if [[ $1 == --version ]]; then
        printf 'fixture npm\n'
    else
        [[ $1 == install && $2 == -g && " $* " == *' @openai/codex '* ]]
    fi
}
export NPM_CONFIG_PREFIX="$HOME/.local" DOTFILES_NPM_FALLBACK_PREFIX="$HOME/.local"
install_nvm_node_tools
[[ ! ${NPM_CONFIG_PREFIX+set} && ! ${DOTFILES_NPM_FALLBACK_PREFIX+set} ]]
EOF

printf 'Fast Node shell activation checks passed\n'
