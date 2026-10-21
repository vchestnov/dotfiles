#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [PROFILE] [OPTIONS]

Profiles: desktop (default), server, nothing, test

Options:
  --dry-run              print the resolved plan without changing the system
  --yes                  apply the normal plan without the confirmation prompt
  --list                 list profiles, components, and groups
  --only LIST            replace profile defaults with comma-separated components
  --enable LIST          add comma-separated components
  --skip LIST            remove comma-separated components
  --allow-risky          authorize noninteractive execution of selected risky components
  -h, --help             show this help

Adding software: see bootstrap/README.md.
EOF
}

parse_arguments() {
    BOOTSTRAP_PROFILE=${BOOTSTRAP_PROFILE:-desktop}
    ONLY_COMPONENTS='' ENABLE_COMPONENTS='' SKIP_COMPONENTS=''
    DRY_RUN=false ASSUME_YES=false ALLOW_RISKY=false LIST_ONLY=false ONLY_SET=false
    local profile_seen=false option
    while (( $# )); do
        case "$1" in
            desktop|server|nothing|test)
                if $profile_seen; then log_error 'Only one profile may be selected.'; return 2; fi
                BOOTSTRAP_PROFILE=$1; profile_seen=true; shift ;;
            --dry-run) DRY_RUN=true; shift ;;
            --yes) ASSUME_YES=true; shift ;;
            --allow-risky) ALLOW_RISKY=true; shift ;;
            --list) LIST_ONLY=true; shift ;;
            --only|--enable|--skip)
                option=$1
                if (( $# < 2 )) || [[ "$2" == --* ]]; then
                    log_error "$option requires a value."; return 2
                fi
                case "$option" in
                    --only) ONLY_COMPONENTS=$2; ONLY_SET=true ;;
                    --enable) ENABLE_COMPONENTS=$2 ;;
                    --skip) SKIP_COMPONENTS=$2 ;;
                esac
                shift 2 ;;
            --only=*) ONLY_COMPONENTS=${1#*=}; ONLY_SET=true; shift ;;
            --enable=*) ENABLE_COMPONENTS=${1#*=}; shift ;;
            --skip=*) SKIP_COMPONENTS=${1#*=}; shift ;;
            -h|--help) usage; exit 0 ;;
            *) log_error "Unknown argument: $1"; usage; return 2 ;;
        esac
    done
}

list_components() {
    local component
    printf 'Profiles: desktop server nothing test\nComponents (in execution order):\n'
    for component in "${COMPONENTS[@]}"; do
        printf '  %-20s %s\n' "$component" "${COMPONENT_METHOD[$component]}"
    done
    printf 'Groups:\n'
    for component in "${COMPONENT_GROUPS[@]}"; do
        printf '  %s = %s\n' "$component" "${GROUP_MEMBERS[$component]}"
    done
}

print_plan() {
    local component
    log_section 'RESOLVED BOOTSTRAP PLAN'
    log_info "Profile: $BOOTSTRAP_PROFILE"
    if (( ${#SELECTED_COMPONENTS[@]} )); then
        for component in "${SELECTED_COMPONENTS[@]}"; do
            printf '  %-20s %s\n' "$component" "${COMPONENT_METHOD[$component]}"
        done
    else
        printf '  (no components selected)\n'
    fi
    if (( ${#SELECTED_RISKY[@]} )); then log_warning "Risky opt-ins: ${SELECTED_RISKY[*]}"; fi
    for component in "${SELECTED_COMPONENTS[@]}"; do
        if [[ -n "${COMPONENT_PLAN[$component]}" ]]; then "${COMPONENT_PLAN[$component]}"; fi
    done
}
