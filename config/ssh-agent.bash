# Sourced Bash configuration: preserve the caller's shell options and agent.
# Clear retired entry points when reloading a shell that used the old helper.
unset -f ssh_find_agent ssh-find-agent

ssh_agent_refresh() {
    local resolver="$HOME/.local/bin/ssh-agent-socket" socket tmux_environment seen_tmux=''
    if [[ ! -x "$resolver" ]]; then
        if [[ " $* " != *' --quiet '* ]]; then
            printf 'SSH agent resolver missing: %s; run makesymlinks.sh server.\n' "$resolver" >&2
        fi
        return 1
    fi
    # Snapshot before probing, so a later tmux change is still noticed by the prompt.
    if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
        if tmux_environment=$(tmux show-environment SSH_AUTH_SOCK 2>/dev/null) \
            && [[ "$tmux_environment" == SSH_AUTH_SOCK=* ]]; then
            seen_tmux=${tmux_environment#SSH_AUTH_SOCK=}
        fi
    fi
    if ! socket=$("$resolver" "$@"); then return 1; fi
    if [[ -z "$socket" || "$socket" == *$'\n'* || ! -S "$socket" || ! -O "$socket" ]]; then return 1; fi
    if [[ "$socket" != "${SSH_AUTH_SOCK:-}" ]]; then unset SSH_AGENT_PID; fi
    export SSH_AUTH_SOCK="$socket"
    _SSH_AGENT_LAST_CURRENT_STATE="$socket:socket"
    _SSH_AGENT_LAST_TMUX_SOCKET=$seen_tmux
    if [[ " $* " != *' --quiet '* ]]; then printf 'SSH_AUTH_SOCK=%s\n' "$socket"; fi
}

ssh_agent_list() {
    "$HOME/.local/bin/ssh-agent-socket" --list
}

_ssh_agent_prompt_refresh() {
    local previous_status=$? tmux_environment socket='' current_state
    if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
        if tmux_environment=$(tmux show-environment SSH_AUTH_SOCK 2>/dev/null) \
            && [[ "$tmux_environment" == SSH_AUTH_SOCK=* ]]; then
            socket=${tmux_environment#SSH_AUTH_SOCK=}
        fi
        current_state="${SSH_AUTH_SOCK:-}:missing"
        if [[ -S "${SSH_AUTH_SOCK:-}" ]]; then current_state="${SSH_AUTH_SOCK:-}:socket"; fi
        if [[ "$socket" != "${_SSH_AGENT_LAST_TMUX_SOCKET:-}" \
            || "$current_state" != "${_SSH_AGENT_LAST_CURRENT_STATE:-}" ]]; then
            _SSH_AGENT_LAST_TMUX_SOCKET=$socket
            if ssh_agent_refresh --quiet --no-discovery; then :; fi
            _SSH_AGENT_LAST_CURRENT_STATE="${SSH_AUTH_SOCK:-}:missing"
            if [[ -S "${SSH_AUTH_SOCK:-}" ]]; then _SSH_AGENT_LAST_CURRENT_STATE="${SSH_AUTH_SOCK:-}:socket"; fi
        fi
    fi
    return "$previous_status"
}

# PROMPT_COMMAND may be a string or array; += retains existing entries in either case.
if [[ " ${PROMPT_COMMAND[*]-} " != *' _ssh_agent_prompt_refresh '* ]]; then
    PROMPT_COMMAND+=(_ssh_agent_prompt_refresh)
fi
if [[ -n "${SSH_AUTH_SOCK:-}${TMUX:-}${SSH_CONNECTION:-}" ]]; then
    if ssh_agent_refresh --quiet; then :; fi
fi
