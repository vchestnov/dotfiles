# git

High-frequency reminders. Check `git status` before a state-changing command.

## Daily flow

```bash
git status -sb
git diff
git diff --staged
git add -p
git commit -m 'describe the change'
git switch branch-name
git switch -c new-branch
git fetch --prune
git pull --ff-only
```

## Inspect history and changes

```bash
git log --oneline --graph --decorate --all
git log -p -- path/to/file
git log -S 'literal text' -- path/to/file       # introduced or removed text
git log -G 'regular expression' -- path/to/file # changed a matching line
git show commit:path/to/file
git diff main...HEAD                           # branch work since it diverged
git grep -n 'pattern'
```

## Undo and recover

```bash
git restore path/to/file                # discard unstaged change
git restore --staged path/to/file       # unstage, keep working change
git commit --amend --no-edit            # add to the last commit
git revert commit                        # new commit that undoes a commit
git reflog                               # find a lost commit or branch tip
git switch -c recovered HEAD@{1}
```

## Branches and remotes

```bash
git branch --show-current
git branch -vv
git branch -d merged-branch
git push -u origin HEAD
git push --force-with-lease             # safer history rewrite
git worktree add ../project-fix fix-branch
```

## Show via picker

```bash
git log --pretty=format:'%h %s' |
  fzf |
  awk '{print $1}' |
  xargs -r -I {} git show {}
```
