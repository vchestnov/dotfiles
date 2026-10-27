# Maintaining the custom suckless tools

Sources live in `${SRC_DIR:-$HOME/soft}/{dwm,dmenu,st,slstatus,slock}`.
Each repository keeps your customizations on `main` and the original suckless
repository as `upstream`. Add your private hosted repository as `origin` when ready.

Bootstrap builds the commits in `config/suckless.lock` from fresh snapshots under
`$XDG_CACHE_HOME/bootstrap/build/suckless`. It does not apply patches, merge upstream,
rewrite remotes, or edit your source checkout. A URL of `-` means the repository
must already exist locally. Keep these repositories backed up until they are hosted.

## Change a feature or configuration

Edit `config.def.h` for defaults, or the relevant source files. `config.h` is
generated and ignored. Shared fonts and colors can still be managed in Xresources.
Starting from a clean `main`, use a branch and commit each feature or fix separately:

```bash
cd ~/soft/dmenu                     # replace dmenu with the tool you want
git switch main
git switch -c feature/my-change
# Edit files; optionally git apply /path/to/a/new.patch once.
git add config.def.h dmenu.c        # stage only files you intentionally changed
git commit
~/dotfiles/scripts/suckless build dmenu
```

Run the binary from the printed build directory to check the changed behavior.
Then merge the checked branch into `main` with `git merge --ff-only feature/my-change`.

## Incorporate upstream changes

Start with committed work. If `origin` is configured, first synchronize `main`
using `git pull --ff-only origin main`. Choose a fresh update branch name:

```bash
cd ~/soft/dmenu
git switch main
git fetch upstream --tags
git switch -c update/upstream-2026-10
git merge upstream/master           # or choose an upstream release tag
```

If there are conflicts, edit the affected files, `git add` them, and run
`git merge --continue`. Use `git merge --abort` to abandon an unfinished merge.
Git remembers conflict resolutions through `rerere`; review any reused changes.

```bash
~/dotfiles/scripts/suckless build dmenu
# Check the binary in the printed directory, then:
git switch main
git merge --ff-only update/upstream-2026-10
# If origin exists: git push origin main
```

Check dwm in a separate X session and check slock locking/unlocking before replacing
your normal binaries. Compilation alone does not check these behaviors.

## Record and install the checked version

```bash
~/dotfiles/scripts/suckless pin dmenu
cd ~/dotfiles
git diff -- config/suckless.lock
./bootstrap.sh nothing --only dwm   # installs all five tools and their integration
```

`pin` requires a clean `main`, builds its committed snapshot, and updates only that
tool's lock entry. Commit the changed lock file with your dotfiles changes.
Bootstrap installs to `/usr/local` using sudo, matching the existing desktop setup.
After starting a dwm build with restartsig support, Alt+Ctrl+Shift+Q loads the
newly installed binary while keeping applications open. The first installation
of restart support requires one logout/login before that shortcut is available.
The tag-preserving build saves each window's tags and monitor automatically,
including assignments to multiple tags. Future restarts restore these assignments.
The first restart from an older build without preservation can still reset tags
once; arrange the windows again after that upgrade. Each monitor's current and
previous tag views and every tag's layout pair, master width and master count
are saved before a restart and restored on the next start. The first upgrade from
monitor-only layout preservation imports that monitor's layout into tag 1;
other tags start from configured defaults. A fresh login uses configured defaults.
Window order can still change. This does not restore applications after logout
or reboot. Run
`xprop _NET_CLIENT_INFO` and click a window to inspect its saved tag bitmask and
monitor number.
Bootstrap keeps the maintained source
repositories in place; it no longer provides a `wipe-suckless` component.

## SSH agent in dwm

The session launcher runs `ssh-agent dwm`, so each desktop login starts an
OpenSSH agent shared by terminals and other programs launched from dwm. The agent
exits when the session ends. ThinkPad Bash startup preserves the inherited agent;
`ssh_agent_start` is no longer needed after logging in to dwm.

The agent starts empty. Add keys once per session, for example:

```bash
ssh-add ~/.ssh/oxford_math
```

To install only an updated session launcher from this repository, run:

```bash
sudo install -m 0755 config/suckless/dwm-session /usr/local/bin/dwm-session
```

Log out and back in to use the updated launcher. Restarting dwm alone keeps the
current session environment.

## Per-tag layouts in dwm

Focus the monitor, select a tag, and choose a layout. For example, on the wide monitor:

- Alt+1, then Alt+U: centeredmaster on tag 1.
- Alt+2, then Alt+T: normal tiling on tag 2.
- Alt+3, then Alt+M: monocle on tag 3.

Each tag on each monitor remembers its own layout, previous layout (Alt+Space),
master width (Alt+H / Alt+L), and master count (Alt+I / Alt+D). These settings and
the current/previous tag views survive dwm restarts. Bar visibility is shared
across tags on each monitor.

For combined tag views, the first-selected tag controls the layout and receives
layout/master-setting changes. If removed from the view, the first remaining tag
in bar order takes control. The all-tags view has separate settings.

## Use centered master in dwm

After installing the new build, press Alt+Ctrl+Shift+Q to restart dwm, then focus
the wide monitor and press Alt+U (`|M|`). Focus Vim and press Alt+Return to make
it the master window. With three or more tiled windows, the master occupies the
middle half of the screen; other windows alternate between the side stacks.
Alt+H / Alt+L adjust the master width, and Alt+I / Alt+D adjust the number of
master windows. Alt+T selects normal tiling on the current tag. Each monitor/tag
keeps its own layout selection across dwm restarts. If you edit `layouts[]`, keep
its symbols unique: saved layouts are identified by symbol, so reordering the array
is safe, while removed or renamed entries fall back to defaults.

In centeredmaster, Alt+K cycles through master windows, the entire right column
from top to bottom, then the entire left column from top to bottom, and wraps
back to master. Alt+J follows the reverse order. Floating windows follow the tiled
columns. Other layouts retain their existing Alt+J / Alt+K bindings.

For a dwm-only installation, run `scripts/suckless pin dwm`, then
`sudo make -C /path/to/printed/build/directory install` using the build directory
printed by that command. See `~/soft/dwm/README.local.md` for patch provenance.

## Add the private remotes later

Create an empty hosted repository per tool, then run in each local repository:

```bash
git remote add origin YOUR_PRIVATE_REPOSITORY_URL
git push -u origin main
git push origin --tags
~/dotfiles/scripts/suckless pin dmenu # use the matching tool name
```

Pinning records `origin`'s URL after verifying that `origin/main` contains the
commit. Bootstrap can then clone it on new machines with Git authentication already
configured. Repository URLs must not contain credentials.

## Migration on 13 October 2026

The installed dmenu, st, slstatus, and slock binaries matched `~/soft` byte for byte.
The installed dwm matched `~/.local/src/dwm`; `~/soft/dwm` has newer upstream source
and newer Zoom rules in `config.def.h`. Those current rules are retained.
The migration left the installed binaries in place.
Pre-migration backups are under `~/.local/state/suckless/migration/`.
Each repository has a `local-migration-2026-10-13` tag for its imported version.

The obsolete `~/.local/src/{dwm,dmenu,st,slstatus,slock,dwm-test}` trees were
subsequently removed after archiving their complete Git and working-tree state to
`~/.local/state/suckless/retired-sources/20261013T152945Z/legacy-suckless.tar.gz`.
The archive includes the staged experimental changes from `dwm-test`. Extract it
into a temporary directory if you need to inspect or recover an older version.
