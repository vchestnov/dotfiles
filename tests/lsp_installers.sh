#!/usr/bin/env bash
set -Eeuo pipefail
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
export HOME="$tmp_dir/home" BOOTSTRAP_TEST_REPO="$repo_dir"
mkdir -p "$HOME"

bash <<'EOF'
set -Eeuo pipefail
source "$BOOTSTRAP_TEST_REPO/bootstrap/lib.sh"
source "$BOOTSTRAP_TEST_REPO/bootstrap/installers/lsp.sh"
SCRIPT_DIR=$BOOTSTRAP_TEST_REPO BIN_DIR="$HOME/bin"
CLANGD_INSTALL_METHOD_DEFAULT=auto
clangd() { printf 'existing clangd\n' >> "$HOME/events"; }
install_clangd_from_source() { printf 'Unexpected LLVM build\n' >&2; exit 1; }
install_python_lsp() { :; }
install_julia_lsp() { :; }
install_launcher_script() { :; }
run_wolfram_code() { :; }
vim() { :; }
install_lsp
CLANGD_INSTALL_METHOD=existing install_lsp
[[ "$(wc -l < "$HOME/events")" == 2 ]]
EOF

bash <<'EOF'
set -Eeuo pipefail
source "$BOOTSTRAP_TEST_REPO/bootstrap/lib.sh"
source "$BOOTSTRAP_TEST_REPO/bootstrap/installers/lsp.sh"
export PYLSP_VENV_DIR="$HOME/broken-venv"
mkdir -p "$PYLSP_VENV_DIR/bin"
printf 'preserve me\n' > "$PYLSP_VENV_DIR/sentinel"
printf '#!/usr/bin/env bash\nexit 1\n' > "$PYLSP_VENV_DIR/bin/python"
chmod +x "$PYLSP_VENV_DIR/bin/python"
command() {
    if [[ "$*" == '-v pipx' ]]; then return 1; fi
    builtin command "$@"
}
python3() {
    [[ "$1 $2" == '-m venv' ]]
    if [[ "$3" == --help ]]; then return 0; fi
    mkdir -p "$3/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$3/bin/python"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$3/bin/pylsp"
    chmod +x "$3/bin/python" "$3/bin/pylsp"
}
install_python_lsp
backups=("$PYLSP_VENV_DIR".backup.*)
[[ ${#backups[@]} == 1 && "$(cat "${backups[0]}/sentinel")" == 'preserve me' ]]
[[ -x "$PYLSP_VENV_DIR/bin/python" && -L "$HOME/.local/bin/pylsp" ]]
EOF
printf 'LSP installer checks passed\n'
