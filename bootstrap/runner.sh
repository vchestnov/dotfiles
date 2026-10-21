#!/usr/bin/env bash
set -Eeuo pipefail

declare -a SELECTED_COMPONENTS=() SELECTED_RISKY=() COMPLETED_COMPONENTS=()
declare -a SKIPPED_COMPONENTS=() INCOMPLETE_COMPONENTS=()
CURRENT_COMPONENT='' COMPONENT_RESULT=success

skip_component() {
    COMPONENT_RESULT=skipped
    log_warning "$CURRENT_COMPONENT skipped: $*"
}

component_incomplete() {
    if [[ "$COMPONENT_RESULT" != skipped ]]; then COMPONENT_RESULT=incomplete; fi
    log_warning "$CURRENT_COMPONENT incomplete: $*"
}

write_run_status() {
    local status=$1 exit_code=${2:-0} state_dir="$XDG_STATE_HOME/bootstrap" state_tmp
    mkdir -p "$state_dir"
    state_tmp=$(mktemp "$state_dir/.last-run.XXXXXX")
    {
        printf 'status=%s\nexit_code=%s\nprofile=%s\n' "$status" "$exit_code" "$BOOTSTRAP_PROFILE"
        printf 'updated_at=%s\n' "$(date --iso-8601=seconds)"
        if [[ "$status" != running ]]; then printf 'finished_at=%s\n' "$(date --iso-8601=seconds)"; fi
        printf 'selected_components=%s\n' "${SELECTED_COMPONENTS[*]}"
        printf 'completed_components=%s\n' "${COMPLETED_COMPONENTS[*]}"
        printf 'skipped_components=%s\n' "${SKIPPED_COMPONENTS[*]}"
        printf 'incomplete_components=%s\n' "${INCOMPLETE_COMPONENTS[*]}"
        printf 'current_component=%s\n' "$CURRENT_COMPONENT"
        if [[ "$status" == failed ]]; then printf 'failed_component=%s\n' "$CURRENT_COMPONENT"; fi
    } > "$state_tmp"
    mv -- "$state_tmp" "$state_dir/last-run"
}

bootstrap_error() {
    local exit_code=$1 line=$2 command=$3
    trap - ERR
    log_error "${CURRENT_COMPONENT:-bootstrap} failed at ${BASH_SOURCE[1]}:$line (exit $exit_code)" >&2
    log_error "Command: $command" >&2
    if ! write_run_status failed "$exit_code"; then log_warning 'Could not record failed run status.' >&2; fi
    exit "$exit_code"
}

preflight() {
    log_section 'PRE-FLIGHT CHECKS'
    if (( EUID == 0 )); then
        log_error 'Run bootstrap as your normal user; individual components request sudo.'; return 1
    fi
    if [[ "$BOOTSTRAP_PROFILE" == desktop ]]; then
        if ! grep -q 'Ubuntu 24.04' /etc/os-release; then log_warning 'This script is designed for Ubuntu 24.04.'; fi
        local available_space
        available_space=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
        if (( available_space < 2097152 )); then log_warning 'Less than 2GB free space is available.'; fi
    fi
    local component
    for component in "${SELECTED_COMPONENTS[@]}"; do
        if ${COMPONENT_SUDO[$component]}; then
            command -v sudo >/dev/null || { log_error "$component requires sudo."; return 1; }
            refresh_sudo
            break
        fi
    done
}

execute_plan() {
    local component final_status=success
    APT_UPDATED=false
    export PATH="$BIN_DIR:${CARGO_HOME:-$XDG_DATA_HOME/cargo}/bin:$PATH"
    # Keep errexit active: if/!/|| around installer calls would disable it in their bodies.
    trap 'bootstrap_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
    write_run_status running
    preflight
    for component in "${SELECTED_COMPONENTS[@]}"; do
        CURRENT_COMPONENT=$component COMPONENT_RESULT=success
        write_run_status running
        cd "$SCRIPT_DIR"
        log_section "COMPONENT: $component"
        "${COMPONENT_INSTALLER[$component]}"
        case "$COMPONENT_RESULT" in
            success) COMPLETED_COMPONENTS+=("$component") ;;
            skipped) SKIPPED_COMPONENTS+=("$component") ;;
            incomplete) INCOMPLETE_COMPONENTS+=("$component") ;;
        esac
        CURRENT_COMPONENT=''
        write_run_status running
    done
    if (( ${#SKIPPED_COMPONENTS[@]} + ${#INCOMPLETE_COMPONENTS[@]} )); then final_status=partial; fi
    write_run_status "$final_status"
    log_section "BOOTSTRAP FINISHED: $final_status"
    log_info "Selected components: ${SELECTED_COMPONENTS[*]:-(none)}"
    if [[ "$final_status" == partial ]]; then
        log_warning "Skipped: ${SKIPPED_COMPONENTS[*]:-(none)}; incomplete: ${INCOMPLETE_COMPONENTS[*]:-(none)}"
    fi
    log_info "Run status: $XDG_STATE_HOME/bootstrap/last-run"
}

bootstrap_main() {
    parse_arguments "$@"
    load_installers
    if $LIST_ONLY; then list_components; return 0; fi
    apply_profile
    if $ONLY_SET; then ENABLED=(); apply_component_list "$ONLY_COMPONENTS" 1; fi
    apply_component_list "$ENABLE_COMPONENTS" 1
    apply_component_list "$SKIP_COMPONENTS" 0
    resolve_plan
    print_plan
    if $DRY_RUN; then log_success 'Dry run completed; no changes were made.'; return 0; fi
    if $ASSUME_YES && (( ${#SELECTED_RISKY[@]} )) && ! $ALLOW_RISKY; then
        log_error 'Risky components require --allow-risky when --yes is used.'; return 2
    fi
    if ! $ASSUME_YES; then
        local confirm
        if ! read -r -p 'Apply this plan? [y/N] ' confirm || [[ ! "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            log_info 'Cancelled.'; return 0
        fi
    fi
    execute_plan
}
