# SSH X11 Forwarding Renewal Notes

## Vim Clipboard After Reconnecting to tmux

Reattaching tmux copies the new SSH client's `DISPLAY` and `XAUTHORITY` into
tmux's session environment. Existing shells and Vim processes keep their original
environment. A surviving Vim can therefore report:

```text
X clipboard copy failed; check DISPLAY and SSH forwarding
```

The remote clipboard provider in `vim/config/clipboard.vim` now retries a failed
copy or paste once using tmux's current `DISPLAY` and `XAUTHORITY`. A working
clipboard does not query tmux or change displays. If recovery fails, Vim restores
its previous environment and reports the underlying `xsel` error. No X11
connection is made during Vim startup.

For an already-open Vim, load the updated provider without restarting:

```vim
:unlet! g:dotfiles_clipboard_config_loaded
:source ~/.vim/config/clipboard.vim
```

Then repeat the copy or paste. The SSH connection that provides the new display
must remain open. Reconnect with X11 forwarding and reattach tmux normally;
`tmux attach -E` suppresses the environment update.

To check the connection from a **new tmux pane** without changing the clipboard:

```bash
printf 'DISPLAY=%s\nXAUTHORITY=%s\n' "$DISPLAY" "${XAUTHORITY-}"
tmux show-environment DISPLAY
tmux show-environment XAUTHORITY
timeout 5 xdpyinfo >/dev/null
```

If this succeeds but Vim still fails, compare Vim's environment with tmux using
`:echo $DISPLAY` and `:echo $XAUTHORITY`. If the new pane also fails, the problem
is in the forwarding connection or X11 authentication; copying tmux's values
cannot repair that connection.

References: [tmux session environment](https://man.openbsd.org/tmux#GLOBAL_AND_SESSION_ENVIRONMENT)
and [OpenSSH X11 forwarding](https://man.openbsd.org/ssh#X11_FORWARDING).

## Current Setup

- Laptop connects to `fire-chief-ash` with `ssh -XAY`.
- On `fire-chief-ash`, `DISPLAY` is preserved.
- Inside a `tmux` session on `fire-chief-ash`, another hop is made to compute nodes with `ssh -XAY <node>`.
- Sometimes that second-hop X forwarding breaks on the compute node.

## Observed Failure

- On the compute node, programs such as Vim may print errors like:

```text
connect localhost port 6010: Connection refused
```

- This means the `DISPLAY` on the compute node still points to an old forwarded X11 port, but the SSH session that created that forwarding channel is no longer usable.

## What Works

Recovery without killing the old `tmux` session:

1. On `fire-chief-ash`, open a new `tmux` window or pane.
2. From that new window, run:

```bash
ssh -XAY <node>
```

3. On the compute node in that fresh session, note the new value of:

```bash
echo "$DISPLAY"
```

4. In the old compute-node shell, run:

```bash
export DISPLAY=<new-value>
```

5. X forwarding starts working again in the old shell.

## Important Limitation

- The revived `DISPLAY` in the old shell depends on the new SSH session that created it.
- If the new `tmux` window/pane is closed, the forwarded X11 channel disappears again.
- Therefore, the “donor” SSH session must stay open.

Practical takeaway:

- Keep one dedicated `tmux` window/pane as an X11 anchor session to the compute node.
- Do not close it while other compute-node shells are borrowing its `DISPLAY`.

## Remaining Shell and Second-Hop Limitations

Vim's recovery updates only that Vim process. Existing shells retain their own
environment. New tmux panes receive the updated environment automatically.

An SSH client already running inside an old pane also retains its original X11
forwarding state. When a second-hop connection depends on an expired first-hop
display, open a new pane and establish a fresh second-hop connection as described
above. Updating Vim on the first machine cannot repair an existing SSH client on
another machine. Automatic donor-session discovery and shell refresh remain
future work.
