---
name: nipreps-release
description: Use when cutting or tagging a release for a NiPreps project (niworkflows, sMRIPrep, fMRIPrep, sdcflows, nibabies, etc.) — creating the annotated version tag from CHANGES.rst, pushing the tag and maintenance branch to upstream, and back-merging to master.
---

# NiPreps Release

## Overview

NiPreps packages version from git tags (`hatch-vcs`, `release-branch-semver`).
Releasing = creating an **annotated tag** whose message is the release's
changelog section, pushing the tag + maintenance branch to `upstream`, then
back-merging the tag into `master`. There is no version file to edit.

## Pre-flight checklist (do NOT tag until all pass)

- [ ] On the maintenance branch `maint/Y.Z.x` (e.g. `maint/1.15.x`), not `master`.
      One branch per minor series: it either starts a new `Y.Z` release series or
      continues an existing one (patch releases land on the same `maint/Y.Z.x`).
- [ ] Working tree clean (`git status` — nothing uncommitted).
- [ ] `CHANGES.rst` has a section whose header matches `TAG` and today's date,
      pared to real user-facing **enhancements and fixes** (drop CI/deps/pre-commit
      noise and anything already shipped in an earlier patch line).
- [ ] CI is green on the branch — including the Docker/conda build, not just pytest.
      A dependency floor bump (e.g. numpy) can break the `micromamba`/`pixi` solve
      even when the pip resolution passes.
- [ ] `upstream` remote points at the canonical `nipreps/<project>` repo.
- [ ] `TAG` is bare semver with **no leading `v`** (e.g. `1.15.0`).

## Release steps

```bash
# from the maintenance branch, tree clean, CHANGES.rst updated
./release.sh 1.15.0 maint/1.15.x   # TAG is X.Y.Z; MAINT_BRANCH is maint/X.Y.x
```

The maintenance branch is always `maint/Y.Z.x` (the `.x` is literal). A `Y.Z.0`
release starts the series on a fresh `maint/Y.Z.x`; later `Y.Z.N` patches reuse
the same branch.

`release.sh` runs:

```bash
git tag -a "$TAG" -F "$CHANGES" -e   # seed tag msg from CHANGES.rst, edit to trim
git push upstream "$TAG"             # publish the tag -> triggers build/publish CI
git push upstream -u "$MAINT_BRANCH" # publish the maintenance branch
```

The `-e` opens `$EDITOR` with the **entire** changelog as the tag message —
**delete everything except this release's section** before saving. That trimmed
text becomes the GitHub release notes.

## After the release is confirmed built/published

```bash
git switch master
git merge --no-ff "$TAG"     # merge the TAG, not the branch
git push upstream master
```

Back-merge the **tag** (`--no-ff`) so master's history contains the release
commit and the version scheme stays monotonic.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Tagging with `v1.15.0` | Breaks the semver/version scheme; NiPreps uses bare `1.15.0`. |
| Not trimming the `-e` tag message | Whole changelog becomes the release notes. |
| Tagging off `master` | Version scheme resolves wrong; tag the maintenance branch. |
| Skipping the Docker/conda build check | pip resolves fine but `micromamba`/`pixi` solve fails on new floors. |
| Merging the branch instead of the tag on back-merge | Loses the clean release-point in history. |
| Dirty working tree at tag time | `hatch-vcs` marks the build dirty / version is off. |

## Files

- `release.sh` — the tag-and-push script (args: `TAG MAINT_BRANCH [CHANGES]`).
