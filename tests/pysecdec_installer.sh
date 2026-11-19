#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
export TEST_PYSECDEC_REPO="$repo_dir" TEST_PYSECDEC_ROOT="$tmp_dir"
mkdir -p "$tmp_dir/bin with spaces"
cat > "$tmp_dir/bin with spaces/python" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1" == -c ]]; then exit 0; fi
[[ "$1 $2" == '-m venv' ]]
printf 'created\n' >> "$TEST_PYSECDEC_ROOT/created"
mkdir -p "$3/bin"
printf 'fixture venv\n' > "$3/pyvenv.cfg"
cp "$TEST_PYSECDEC_ROOT/venv-python" "$3/bin/python"
EOF
cat > "$tmp_dir/venv-python" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1" == -c ]]; then exit 0; fi
printf '%s\n' "$*" >> "$TEST_PYSECDEC_ROOT/pip-commands"
if [[ "$*" == *' install '* ]]; then
    [[ "$*" == '-m pip --require-virtualenv install --prefer-binary pySecDec==1.6.6' ]]
    [[ "$PIP_CACHE_DIR" == "$TEST_PYSECDEC_ROOT/cache/bootstrap/pip" ]]
fi
EOF
chmod +x "$tmp_dir/bin with spaces/python" "$tmp_dir/venv-python"
cat > "$tmp_dir/install" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
source "$TEST_PYSECDEC_REPO/bootstrap/lib.sh"
source "$TEST_PYSECDEC_REPO/bootstrap/installers/pysecdec.sh"
SCRIPT_DIR=$TEST_PYSECDEC_REPO
XDG_DATA_HOME="$TEST_PYSECDEC_ROOT/data with spaces"
XDG_CACHE_HOME="$TEST_PYSECDEC_ROOT/cache"
PYSECDEC_PYTHON="$TEST_PYSECDEC_ROOT/bin with spaces/python"
PYSECDEC_VERSION=1.6.6
install_pysecdec
EOF

bash "$tmp_dir/install" > "$tmp_dir/install.log"
bash "$tmp_dir/install" >> "$tmp_dir/install.log"
[[ $(wc -l < "$tmp_dir/created") == 1 ]] || fail 'rerun recreated the virtual environment'
[[ $(grep -c 'pySecDec==1.6.6' "$tmp_dir/pip-commands") == 2 ]] || fail 'installer lost the release pin'
[[ $(grep -c 'pip check' "$tmp_dir/pip-commands") == 2 ]] || fail 'installer did not verify dependency consistency'

mkdir "$tmp_dir/unrelated"
printf 'keep me\n' > "$tmp_dir/unrelated/sentinel"
if PYSECDEC_VENV_DIR="$tmp_dir/unrelated" bash "$tmp_dir/install" > "$tmp_dir/refusal.log" 2>&1; then
    fail 'accepted an unrelated directory as a virtual environment'
fi
[[ $(cat "$tmp_dir/unrelated/sentinel") == 'keep me' ]] || fail 'modified the unrelated directory'
ln -s "$tmp_dir/data with spaces/pysecdec" "$tmp_dir/linked-venv"
if PYSECDEC_VENV_DIR="$tmp_dir/linked-venv" bash "$tmp_dir/install" > "$tmp_dir/symlink.log" 2>&1; then
    fail 'installed through a symlinked environment'
fi

# makesymlinks exposes repository scripts through ~/.local/bin symlinks.
ln -s "$repo_dir/scripts/check-pysecdec-box1l" "$tmp_dir/check-box1l"
if PYSECDEC_VENV_DIR="$tmp_dir/missing" bash "$tmp_dir/check-box1l" > "$tmp_dir/check.log" 2>&1; then
    fail 'box1L check accepted a missing environment'
fi
grep -q 'Install pySecDec first' "$tmp_dir/check.log" || fail 'symlinked box1L check could not locate the repository'
printf 'pySecDec installer checks passed\n'
