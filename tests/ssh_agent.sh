#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
vim_bin=$(command -v vim) || vim_bin=''
export HOME="$tmp_dir/home with spaces" TMPDIR="$tmp_dir/tmp"
export TEST_AGENT_DIR="$tmp_dir" SSH_AGENT_CHECK_TIMEOUT=0.05
export PATH="$tmp_dir/bin:$PATH"
mkdir -p "$HOME/.ssh/agent" "$HOME/.local/bin" "$TMPDIR/ssh-fixture" "$tmp_dir/bin"
resolver="$repo_dir/scripts/ssh-agent-socket"
ln -s "$resolver" "$HOME/.local/bin/ssh-agent-socket"
current="$HOME/.ssh/agent/s.fixture.agent.current"
first="$HOME/.ssh/agent/s.fixture.sshd.first"
second="$HOME/.ssh/agent/s.fixture.sshd.second"
legacy="$TMPDIR/ssh-fixture/agent.123"
python3 - "$current" "$first" "$second" "$legacy" <<'PY'
import socket, sys
for path in sys.argv[1:]:
    sock = socket.socket(socket.AF_UNIX)
    sock.bind(path)
    sock.close()
PY
for socket in "$current" "$first" "$second" "$legacy"; do printf '2\n' > "$socket.status"; done
printf 'preserved\n' > "$HOME/.ssh/agent/sentinel"

cat > "$tmp_dir/bin/ssh-add" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$SSH_AUTH_SOCK" >> "$TEST_AGENT_DIR/probes"
[[ -f "$SSH_AUTH_SOCK.status" ]] || exit 2
status=$(cat "$SSH_AUTH_SOCK.status")
if [[ "$status" == hang ]]; then sleep 5; exit 2; fi
exit "$status"
EOF
cat > "$tmp_dir/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "$*" == 'show-environment SSH_AUTH_SOCK' ]]
[[ -s "$TEST_AGENT_DIR/tmux-socket" ]] || exit 1
printf 'SSH_AUTH_SOCK=%s\n' "$(cat "$TEST_AGENT_DIR/tmux-socket")"
EOF
chmod +x "$tmp_dir/bin/ssh-add" "$tmp_dir/bin/tmux"

export SSH_AUTH_SOCK="$current" TMUX=fixture
printf '%s\n' "$first" > "$tmp_dir/tmux-socket"
printf '0\n' > "$current.status"
printf '0\n' > "$first.status"
[[ "$("$resolver")" == "$current" ]] || fail 'working current agent was replaced'
printf '1\n' > "$current.status"
[[ "$("$resolver")" == "$current" ]] || fail 'reachable empty agent was replaced'
printf '2\n' > "$current.status"
[[ "$("$resolver")" == "$first" ]] || fail 'tmux agent was not used for a stale pane'

found=$(TMUX='' SSH_AUTH_SOCK='' "$resolver")
[[ "$found" == "$first" ]] || fail 'modern forwarded socket was not discovered'
printf '2\n' > "$first.status"
printf '0\n' > "$legacy.status"
found=$(TMUX='' SSH_AUTH_SOCK='' "$resolver")
[[ "$found" == "$legacy" ]] || fail 'legacy forwarded socket was not discovered'
printf '2\n' > "$legacy.status"
printf '0\n' > "$first.status"
printf '0\n' > "$second.status"
if TMUX='' SSH_AUTH_SOCK='' "$resolver" --quiet > "$tmp_dir/ambiguous" 2>&1; then
    fail 'ambiguous agents were selected automatically'
fi
[[ ! -s "$tmp_dir/ambiguous" ]] || fail 'quiet mode produced output'
found=$(printf '2\n' | TMUX='' SSH_AUTH_SOCK='' "$resolver" --choose 2>"$tmp_dir/choices")
[[ "$found" == "$second" ]] || fail 'interactive selection failed'

printf 'hang\n' > "$first.status"
found=$(TMUX='' SSH_AUTH_SOCK='' "$resolver")
[[ "$found" == "$second" ]] || fail 'hung agent prevented fallback'
[[ -S "$first" && -S "$current" && -f "$HOME/.ssh/agent/sentinel" ]] || fail 'discovery deleted socket paths'
printf '2\n' > "$first.status"
: > "$tmp_dir/probes"
if "$resolver" --no-discovery --quiet > "$tmp_dir/no-discovery"; then
    fail 'prompt mode scanned beyond current and tmux agents'
fi
if grep -qxF "$second" "$tmp_dir/probes"; then fail 'prompt mode performed a discovery scan'; fi

printf '0\n' > "$first.status"
printf '%s\n' "$first" > "$tmp_dir/tmux-socket"
export SSH_AUTH_SOCK="$current" SSH_AGENT_PID=123 TMUX=fixture
PROMPT_COMMAND='printf existing'
ssh_find_agent() { printf 'retired helper\n'; }
ssh-find-agent() { ssh_find_agent "$@"; }
source "$repo_dir/config/ssh-agent.bash"
for helper in ssh_find_agent ssh-find-agent; do
    if declare -F "$helper" >/dev/null; then fail "retired function remains loaded: $helper"; fi
done
[[ "$SSH_AUTH_SOCK" == "$first" && ! ${SSH_AGENT_PID+present} ]] || fail 'shell refresh did not update its environment'
[[ "${PROMPT_COMMAND[0]}" == 'printf existing' ]] || fail 'prompt command was overwritten'
ssh_agent_list > "$tmp_dir/listed-agents"
grep -qxF "$first" "$tmp_dir/listed-agents" || fail 'shell command did not list the forwarded agent'
: > "$tmp_dir/probes"
_ssh_agent_prompt_refresh
[[ ! -s "$tmp_dir/probes" ]] || fail 'first prompt repeated the startup agent probe'
source "$repo_dir/config/ssh-agent.bash"
[[ ${#PROMPT_COMMAND[@]} == 2 ]] || fail 'prompt hook was installed twice'

printf '2\n' > "$first.status"
printf '%s\n' "$second" > "$tmp_dir/tmux-socket"
_ssh_agent_prompt_refresh
[[ "$SSH_AUTH_SOCK" == "$second" ]] || fail 'prompt hook did not recover after reconnecting'
: > "$tmp_dir/probes"
_ssh_agent_prompt_refresh
[[ ! -s "$tmp_dir/probes" ]] || fail 'unchanged prompt probed the agent again'
set +e
(exit 7)
_ssh_agent_prompt_refresh
prompt_status=$?
set -e
[[ "$prompt_status" == 7 ]] || fail 'prompt hook lost the previous command status'

# An unavailable unchanged tmux agent must not stall every subsequent prompt.
printf '2\n' > "$second.status"
export SSH_AUTH_SOCK="$HOME/missing-socket"
_ssh_agent_prompt_refresh
: > "$tmp_dir/probes"
_ssh_agent_prompt_refresh
[[ ! -s "$tmp_dir/probes" ]] || fail 'prompt hook repeatedly retried a failed socket'
printf '0\n' > "$second.status"

if [[ -n "$vim_bin" ]]; then
    sed -n '/^function! RefreshSSHAuthSock()/,/^command! RefreshSSHAuthSock/p' "$repo_dir/vimrc" > "$tmp_dir/refresh.vim"
    cat > "$tmp_dir/check.vim" <<'EOF'
execute 'source ' . fnameescape($TEST_AGENT_DIR . '/refresh.vim')
RefreshSSHAuthSock
call assert_equal($TEST_AGENT_EXPECTED, $SSH_AUTH_SOCK)
if !empty(v:errors)
    call writefile(v:errors, $TEST_AGENT_DIR . '/vim-errors')
    cquit 1
endif
qa!
EOF
    SSH_AUTH_SOCK="$current" TEST_AGENT_EXPECTED="$second" \
        "$vim_bin" -Nu NONE -n -i NONE -X -es -S "$tmp_dir/check.vim"
fi
printf 'SSH agent refresh checks passed\n'
