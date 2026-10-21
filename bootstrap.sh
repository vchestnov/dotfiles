#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu desktop and user-local server setup. See bootstrap/README.md to add software.
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/bootstrap/paths.sh"
source "$SCRIPT_DIR/bootstrap/versions.sh"
source "$SCRIPT_DIR/bootstrap/lib.sh"
source "$SCRIPT_DIR/bootstrap/registry.sh"
source "$SCRIPT_DIR/bootstrap/components.sh"
source "$SCRIPT_DIR/bootstrap/profiles.sh"
source "$SCRIPT_DIR/bootstrap/cli.sh"
source "$SCRIPT_DIR/bootstrap/runner.sh"

bootstrap_main "$@"
