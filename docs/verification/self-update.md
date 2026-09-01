# Self-update verification

Active evidence that `/updatefirstmate` advances a firstmate home from its own `origin`.
The procedure this evidence exercises is owned by [`updatefirstmate`](../../.agents/skills/updatefirstmate/SKILL.md) for the agent path and by [`CONTRIBUTING.md`](../../CONTRIBUTING.md) ("Fork remotes and upstream sync") for the maintainer path.

## Origin is the only update source

Verified 2026-09-01 against `cm-maple7/firstmate` with a throwaway home cloned from the fork and deliberately set one commit behind its default branch.

Setup:

```sh
git clone https://github.com/cm-maple7/firstmate.git "$HOME_DIR"
git -C "$HOME_DIR" remote -v
origin	https://github.com/cm-maple7/firstmate.git (fetch)
origin	https://github.com/cm-maple7/firstmate.git (push)

git -C "$HOME_DIR" reset --hard HEAD~1
git -C "$HOME_DIR" log --oneline -1
d77251e fix(bin): absorb background-run stale wakes and trust declared pauses over ci-monitoring (#2)
```

Run:

```sh
FM_ROOT_OVERRIDE="$HOME_DIR" FM_HOME="$HOME_DIR" bash bin/fm-update.sh
firstmate: updated d77251e..6aa4beb (instructions changed: AGENTS.md, bin, .agents/skills)
reread-firstmate: yes
nudge-secondmates: none

git -C "$HOME_DIR" log --oneline -1
6aa4beb Merge pull request #5 from cm-maple7/fm/fm-fork-as-origin-followthrough
```

The home advanced by fast-forward to the fork's default branch, and the updater reported the tracked instruction surface as changed so the caller re-reads `AGENTS.md`.
`6aa4beb` is the merge that landed the upstream sync on the fork, so this run also demonstrates the full chain: upstream work reaches a home only after landing on the fork's own default branch.

Refresh this record by repeating the three commands above whenever the update path or the fork's remote layout changes.

## Pool worktrees inherit the primary checkout's remotes

Verified 2026-09-01 on the same fork.
Treehouse pool worktrees are `git worktree` entries sharing the primary checkout's git directory, so they read its remote configuration rather than defining their own.

```sh
git -C "$POOL_WORKTREE" rev-parse --git-common-dir
/Users/charlie/src/firstmate/.git

git -C "$POOL_WORKTREE" remote get-url origin
https://github.com/cm-maple7/firstmate.git
```

Correcting the remotes once in the primary checkout is therefore what makes every existing and future pool worktree correct; no per-worktree repair step exists or is needed.
