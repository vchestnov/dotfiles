# Codex permissions and unattended work

Codex can work independently within its configured permissions. Longer tasks
need enough filesystem and network access, an approval policy suited to
unattended work, and separate Linux privileges for administrator operations.

Reference: Codex CLI 0.169.0, inspected on 2026-11-15. The access table below
describes the dotfiles session at that time. Check `/status`, `/permissions`,
and `command codex --help` when using this later.

## What currently requires approval

The session uses a workspace-write sandbox: ordinary files in this repository
and temporary directories are writable; command network access is restricted.

| Operation | Session restriction |
| --- | --- |
| Edit ordinary repository files and run local checks | Allowed without confirmation, within the sandbox |
| Write outside the repository or temporary directories | Requires approval, including installs into `~/.local`, links into `~/.config`, and changes to `/etc` |
| Download dependencies or clone and fetch repositories | Requires approval for command network access |
| Write protected repository paths such as `.git`, `.agents`, `.codex`, or `.aws` | Requires approval, including Git operations that write metadata |
| Launch GUI applications | Requires escalation |
| Perform destructive actions without prior authorization | Requires confirmation |

Codex's sandbox determines what commands can access. Its approval policy
determines when an action needs review. Linux ownership and `sudo` permissions
apply separately. Trusting a repository does not grant unrestricted access.
See [agent approvals and security](https://learn.chatgpt.com/docs/agent-approvals-security).

## Automatic approval review

For longer tasks, start with **Approve for me**. In an interactive CLI session,
open `/permissions` and select that mode when available. For a batch task:

```bash
command codex exec -C "$HOME/dotfiles" --approve-for-me \
  -o /tmp/codex-overnight-summary.txt \
  "Complete TASK, run the required checks, and report changes and blockers."
```

Replace `TASK` with a concrete objective and completion criteria. `command codex`
bypasses this repository's Bash alias, which otherwise selects the shared
`dotfiles` profile. Add `--profile dotfiles` explicitly if those preferences
are wanted.

Eligible approval requests go to a separate reviewer agent. The sandbox remains
in place, and approved escalations can proceed without waiting for a person.
Denials can still stop progress, so automatic review does not guarantee an
unattended finish. See [automatic approval review](https://learn.chatgpt.com/docs/sandboxing/auto-review).

To reduce routine escalations, add only the directories the task needs with
`--add-dir /path`. To enable command network access in workspace-write mode,
add this CLI option:

```bash
-c sandbox_workspace_write.network_access=true
```

For example, allowing writes to `"$HOME/soft"` covers source builds there;
allowing `"$HOME/.local"` covers user-local installs. These grants expand
access and should match the authorized task. See
[network access](https://learn.chatgpt.com/docs/agent-approvals-security#network-access).

## Full access

When broad access is intentional:

```bash
command codex exec -C "$HOME/dotfiles" \
  --dangerously-bypass-approvals-and-sandbox \
  -o /tmp/codex-overnight-summary.txt \
  "Complete TASK, run the required checks, and report changes and blockers."
```

This removes Codex's local sandbox and command approval prompts. Commands can
affect everything the Linux account can access. Prefer a dedicated VM or
container when this level of access is necessary. Managed requirements can
still restrict which permission modes are available. See
[sandbox and approval combinations](https://learn.chatgpt.com/docs/agent-approvals-security#common-sandbox-and-approval-combinations).

`--ask-for-approval never` alone does not grant additional access. It suppresses
approval prompts; operations blocked by the sandbox fail instead.

## Reusable settings

For a reusable automatic-review preset, create a host-local profile at
`${CODEX_HOME:-$HOME/.codex}/overnight.config.toml`:

```toml
approval_policy = "on-request"
approvals_reviewer = "auto_review"
sandbox_mode = "workspace-write"

# Optional: enable command network access for tasks that need it.
[sandbox_workspace_write]
network_access = true
```

Select it with `command codex exec --profile overnight -C "$HOME/dotfiles" "TASK"`.
In this CLI version, named profiles are separate files rather than
`[profiles.NAME]` tables in the base config. See
[configuration profiles](https://learn.chatgpt.com/docs/config-file/config-advanced#profiles).

The repository's [shared Codex defaults](../../config/codex/dotfiles.config.toml)
contain UI and model preferences. `makesymlinks.sh nothing --codex` merges these
into a regular local `dotfiles.config.toml` with a local defaults snapshot.
Codex can save trust records and preference changes there without modifying Git.
Later syncs preserve local overrides and apply shared updates to unchanged defaults.
See [shared Codex preferences](../../README.md#shared-codex-cli-preferences).
Machine-specific permission choices can also stay in a separate local profile.

## Linux administrator access and overnight runs

Neither automatic review nor full access grants Linux `root` privileges.
Unattended administrator operations such as `apt install` also need suitable
OS privileges, such as narrowly scoped passwordless `sudo` permissions or a
prepared VM. A cached `sudo` login can expire overnight. Avoid running the
entire agent as root merely to allow a few installation commands.

The [bootstrap script](../../bootstrap.sh) has independent confirmation gates:
`--yes` accepts its execution plan, and noninteractive risky components also
require `--allow-risky`. Codex approval settings do not answer script prompts
or provide a `sudo` password.

Run long tasks in `tmux` or a service, keep the machine awake, and give the task
explicit authorization for intended installs and system changes. Define which
checks must pass and what should happen when blocked. The examples write their
final report to `/tmp`; choose a persistent location for reports you want to
retain across reboots.
