#!/usr/bin/env bash
#
# Tag and push a NiPreps release.
#
# Usage: release.sh <TAG> <MAINT_BRANCH> [CHANGES_FILE]
#   TAG           version to tag, e.g. 1.15.0 (no leading "v" in NiPreps)
#   MAINT_BRANCH  maintenance branch to publish, e.g. maint/1.15.x
#   CHANGES_FILE  changelog to seed the tag message (default: CHANGES.rst)
#
# The annotated tag message is seeded from the ENTIRE changelog and opened in
# $EDITOR (-e): trim it down to just this release's section before saving.
set -eux

TAG=$1
MAINT_BRANCH=$2
CHANGES=${3:-"CHANGES.rst"}

git tag -a "$TAG" -F "$CHANGES" -e
git push upstream "$TAG"
git push upstream -u "$MAINT_BRANCH"

# After the release is confirmed built/published, back-merge into master:
#
#   git switch master
#   git merge --no-ff "$TAG"
#   git push upstream master
