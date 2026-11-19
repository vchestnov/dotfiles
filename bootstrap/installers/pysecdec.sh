#!/usr/bin/env bash
set -Eeuo pipefail

install_pysecdec() {
    local python="${PYSECDEC_PYTHON:-python3}"
    local venv="${PYSECDEC_VENV_DIR:-$XDG_DATA_HOME/pysecdec}"
    local required

    for required in "$python" c++ make; do
        if ! command -v "$required" >/dev/null 2>&1; then
            log_error "pySecDec requires $required; provision it before rerunning this component."
            return 1
        fi
    done
    "$python" -c 'import sys; assert sys.version_info >= (3, 8), "pySecDec requires Python 3.8 or newer"'

    if [[ -L "$venv" ]]; then
        log_error "Refusing to install through a symlinked virtual environment: $venv"
        return 1
    fi
    if [[ -e "$venv" ]]; then
        if [[ ! -f "$venv/pyvenv.cfg" || ! -x "$venv/bin/python" ]]; then
            log_error "Preserving an unrecognized or broken environment at $venv; select another PYSECDEC_VENV_DIR or move it aside."
            return 1
        fi
    else
        log_info "Creating isolated Python environment: $venv"
        mkdir -p "$(dirname "$venv")"
        "$python" -m venv "$venv"
    fi

    # Check isolation before pip can modify an existing installation.
    "$venv/bin/python" -c 'import sys; assert sys.prefix != sys.base_prefix, "Expected an isolated virtual environment"'
    log_info "Installing pySecDec $PYSECDEC_VERSION into $venv"
    PIP_CACHE_DIR="$XDG_CACHE_HOME/bootstrap/pip" \
        "$venv/bin/python" -m pip --require-virtualenv install --prefer-binary "pySecDec==$PYSECDEC_VERSION"
    "$venv/bin/python" -m pip check
    "$venv/bin/python" -c 'import pySecDec; print("pySecDec", pySecDec.__version__)'
    log_success "pySecDec is ready; activate with: source \"$venv/bin/activate\""
    log_info "Run the numerical installation check with: $SCRIPT_DIR/scripts/check-pysecdec-box1l"
}
