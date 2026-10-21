#!/usr/bin/env bash
set -Eeuo pipefail

# Registration order is both the displayed plan and the installation order.
declare -a COMPONENTS=() RISKY_COMPONENTS=() COMPONENT_GROUPS=()
declare -A COMPONENT_INSTALLER=() COMPONENT_FILE=() COMPONENT_METHOD=()
declare -A COMPONENT_SUDO=() COMPONENT_REQUIRES=() COMPONENT_PLAN=()
declare -A GROUP_MEMBERS=() ENABLED=()

register_component() {
    local name=$1 option installer='' file='' method='' sudo=false risky=false requires='' plan=''
    shift
    [[ "$name" =~ ^[a-z][a-z0-9-]*$ && -z "${COMPONENT_INSTALLER[$name]:-}" ]] || {
        log_error "Invalid or duplicate component: $name"; return 1;
    }
    while (( $# )); do
        option=$1
        (( $# >= 2 )) || { log_error "$name: missing value for $option"; return 1; }
        case "$option" in
            --installer) installer=$2 ;;
            --file) file=$2 ;;
            --method) method=$2 ;;
            --sudo) sudo=$2 ;;
            --risky) risky=$2 ;;
            --requires) requires=$2 ;;
            --plan) plan=$2 ;;
            *) log_error "$name: unknown registration option $option"; return 1 ;;
        esac
        shift 2
    done
    [[ "$installer" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ && "$file" =~ ^[a-z0-9-]+\.sh$ && -n "$method" ]] || {
        log_error "$name needs an installer, file, and method"; return 1;
    }
    [[ "$sudo" == true || "$sudo" == false ]] && [[ "$risky" == true || "$risky" == false ]] || {
        log_error "$name: --sudo and --risky must be true or false"; return 1;
    }
    COMPONENTS+=("$name")
    COMPONENT_INSTALLER[$name]=$installer
    COMPONENT_FILE[$name]=$file
    COMPONENT_METHOD[$name]=$method
    COMPONENT_SUDO[$name]=$sudo
    COMPONENT_REQUIRES[$name]=$requires
    COMPONENT_PLAN[$name]=$plan
    if $risky; then RISKY_COMPONENTS+=("$name"); fi
}

register_group() {
    COMPONENT_GROUPS+=("$1")
    GROUP_MEMBERS[$1]=$2
}

load_installers() {
    local component file requirement member
    local -a requirements=() members=()
    local -A loaded=() seen=()
    for component in "${COMPONENTS[@]}"; do
        file=${COMPONENT_FILE[$component]}
        if [[ -z "${loaded[$file]:-}" ]]; then
            source "$SCRIPT_DIR/bootstrap/installers/$file"
            loaded[$file]=1
        fi
        declare -F "${COMPONENT_INSTALLER[$component]}" >/dev/null || {
            log_error "$component: installer function is missing"; return 1;
        }
        if [[ -n "${COMPONENT_PLAN[$component]}" ]]; then
            declare -F "${COMPONENT_PLAN[$component]}" >/dev/null || {
                log_error "$component: plan function is missing"; return 1;
            }
        fi
        IFS=',' read -r -a requirements <<< "${COMPONENT_REQUIRES[$component]}"
        for requirement in "${requirements[@]}"; do
            [[ -n "${seen[$requirement]:-}" ]] || {
                log_error "$component: register prerequisite $requirement earlier"; return 1;
            }
        done
        seen[$component]=1
    done
    for component in "${COMPONENT_GROUPS[@]}"; do
        [[ -z "${COMPONENT_INSTALLER[$component]:-}" ]] || {
            log_error "$component is both a group and a component"; return 1;
        }
        IFS=',' read -r -a members <<< "${GROUP_MEMBERS[$component]}"
        for member in "${members[@]}"; do
            [[ -n "${seen[$member]:-}" ]] || { log_error "$component: unknown member $member"; return 1; }
        done
    done
}

component_enabled() { [[ "${ENABLED[$1]:-0}" == 1 ]]; }

set_component() {
    local name=$1 value=$2
    if [[ -n "${GROUP_MEMBERS[$name]:-}" ]]; then
        apply_component_list "${GROUP_MEMBERS[$name]}" "$value"
    elif [[ -n "${COMPONENT_INSTALLER[$name]:-}" ]]; then
        ENABLED[$name]=$value
        if (( value )); then apply_component_list "${COMPONENT_REQUIRES[$name]}" 1; fi
    else
        log_error "Unknown component: $name"
        return 2
    fi
}

apply_component_list() {
    local list=$1 value=$2 item
    local -a items=()
    [[ -n "$list" ]] || return 0
    IFS=',' read -r -a items <<< "$list"
    for item in "${items[@]}"; do
        [[ -n "$item" ]] || continue
        set_component "$item" "$value"
    done
}

resolve_plan() {
    local component requirement
    local -a requirements=()
    SELECTED_COMPONENTS=() SELECTED_RISKY=()
    for component in "${COMPONENTS[@]}"; do
        component_enabled "$component" || continue
        IFS=',' read -r -a requirements <<< "${COMPONENT_REQUIRES[$component]}"
        for requirement in "${requirements[@]}"; do
            component_enabled "$requirement" || {
                log_error "$component requires $requirement; remove '--skip $requirement' or skip $component too."
                return 2
            }
        done
        SELECTED_COMPONENTS+=("$component")
    done
    for component in "${RISKY_COMPONENTS[@]}"; do
        if component_enabled "$component"; then SELECTED_RISKY+=("$component"); fi
    done
}
