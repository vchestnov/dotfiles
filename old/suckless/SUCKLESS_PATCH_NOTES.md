> Archived patch troubleshooting notes. Current maintenance follows
> [SUCKLESS_WORKFLOW.md](../../SUCKLESS_WORKFLOW.md); bootstrap no longer reapplies
> these patches. Commands below describe the retired layout. Patch snapshots now
> live in [patches/](patches/) beside this note.

# Resolving suckless patch failures

Your bootstrap is `/home/seva/dotfiles/bootstrap.sh`. Source trees are under
`/home/seva/soft/{dwm,dmenu,st,slstatus,slock}`. The `dwm` component rebuilds all five:

```bash
cd /home/seva/dotfiles
./bootstrap.sh --only dwm
```

## 1. Identify the actual tool and patch

Read the last `Configuring ...` line. A patch name such as `xresources` occurs in
several tools. Find its call in bootstrap; line numbers change after edits:

```bash
rg -n 'apply_patch|git_apply_patch' /home/seva/dotfiles/bootstrap.sh
```

Downloaded patches are saved inside the tool's source directory, for example
`/home/seva/soft/st/xresources.patch` or `/home/seva/soft/dwm/center.patch`.
Repository patches live under `/home/seva/dotfiles/patches/`.

## 2. Check both directions without changing files

Example: st's downloaded Xresources patch:

```bash
cd /home/seva/soft/st
git status --short
patch --batch --forward --dry-run -p1 < xresources.patch
patch --batch --force --dry-run -R -p1 < xresources.patch
```

`-p1` removes the initial `a/` or `b/` from patch paths. Forward success means the
patch can be applied; reverse success means it is already applied. If both fail,
inspect the failed hunks: the source version, earlier patches, or later edits may
have changed their context. **Do not reverse an installed patch to fix detection.**

dmenu's local Xresources patch uses `git apply` instead:

```bash
cd /home/seva/soft/dmenu
git apply --check /home/seva/dotfiles/patches/dmenu/dmenu-xresources-combined.diff
git apply --reverse --check /home/seva/dotfiles/patches/dmenu/dmenu-xresources-combined.diff
```

These checks print the failed files and hunks without modifying the source.

## 3. Decide whether it is already installed

Compare the patch's added lines (`+`) with the source:

```bash
cd /home/seva/soft/st
less xresources.patch
git diff -- config.def.h x.c
rg -n 'resource_load|config_init|background|foreground|cursorColor' x.c config.def.h
```

In our st case, the implementation already existed. Bootstrap had corrected color
indices to background `259`, foreground `258`, and cursor `256`, so the original
patch could no longer be reversed exactly. dwm's center patch similarly existed,
but a later patch had changed the rule table.

When the complete implementation exists, update its bootstrap branch to recognize
it and skip reapplication. Check several distinctive parts, including configuration
and the function call; a single matching symbol can also occur in a partial patch.
Keep the normal patch call for source trees without the feature.

## 4. Resolve a genuine conflict in a temporary copy

Example: adapting the combined slock patch to a new upstream version:

```bash
patch_work=$(mktemp -d /tmp/slock-patch.XXXXXX)
cp -a /home/seva/soft/slock "$patch_work/before"
cp -a /home/seva/soft/slock "$patch_work/after"
cd "$patch_work/after"
patch --batch --forward -p1 < /home/seva/dotfiles/patches/slock/slock-capslock-xresources-message-patches.diff
rg --files -g '*.rej'
```

Here the patch really runs: successful hunks are applied, and failed hunks are
saved as `.rej` files. Open each rejection and its source file with `vim`; manually
adapt the rejected additions to the current code. Preserve upstream behavior and
avoid duplicating changes already present. Keep your live checkout untouched.

Build the edited copy using the patched defaults:

```bash
cp config.def.h config.h
make clean
make -j2
./slock -v
```

This checks compilation and version output. It does not install or test locking.

Save only the edits relative to the **before-patch snapshot**, including every
changed source/configuration file:

```bash
for file in config.def.h config.mk slock.1 slock.c util.h; do
    diff -u --label "a/$file" --label "b/$file" \
        "$patch_work/before/$file" "$patch_work/after/$file" || {
        [[ $? -eq 1 ]] || exit 1
    }
done > "$patch_work/slock-rebased.diff"

cd "$patch_work/before"
git apply --check "$patch_work/slock-rebased.diff"
```

`diff` exits with status `1` when it finds differences; the loop accepts that.
Once the check passes, copy the new patch into the repository:

```bash
cp "$patch_work/slock-rebased.diff" \
    /home/seva/dotfiles/patches/slock/slock-capslock-xresources-message-patches.diff
```

Generate patches against the state immediately before their bootstrap call,
including any prerequisite patches. Avoid including unrelated local edits.
Do not use `git reset --hard`, `git clean`, or `wipe-suckless` to resolve conflicts.

## 5. Validate and retry

If you edited bootstrap, run its required checks:

```bash
cd /home/seva/dotfiles
bash -n bootstrap.sh makesymlinks.sh tests/bootstrap_cli.sh
bash tests/bootstrap_cli.sh
./bootstrap.sh desktop --dry-run
./bootstrap.sh server --dry-run
git diff --check
./bootstrap.sh --only dwm
```

On the next rebuild, installed patches should be recognized as already applied.
If compilation fails after patching, check that `config.h` was refreshed from the
patched `config.def.h`. Bootstrap does this in its configuration stage.
