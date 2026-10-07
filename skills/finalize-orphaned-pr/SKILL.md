---
name: finalize-orphaned-pr
description: >
  Use when the user points to an existing, stale, abandoned, or orphaned pull request
  (often another contributor's) and wants it cleaned up, finished, revived, or made
  mergeable. Triggers include a PR URL or number plus "finalize", "clean up", "finish",
  "get this ready to merge", or "orphaned PR".
---

# Finalize an Orphaned PR

Get someone else's PR mergeable **with the smallest faithful diff**. You are finishing
their work, not redesigning it.

Do not stage, commit, push, or rebase — leave changes uncommitted on the PR branch.
`gh pr checkout <n>` and `git fetch` are fine. Check for a `.agents/` directory.

**Repo-specific criteria:** if `repos/<repo-name>.md` exists next to this file, read it
before step 4 — it adds criteria and steps for that repo.

## Acceptance criteria (all repos)

1. **Reasonable size** — one feature. Monolith with several? Propose a split and stop.
2. **Basic behavior tested** — real assertions on the caller's contract; run `/assess-tests`.
3. **Coverage does not decrease** — project and patch, including branch partials.
4. Plus any criteria from the repo file.

## Steps

1. **Intake.** `gh pr view <n> --json title,body,files,commits,comments,reviews,maintainerCanModify,baseRefOid`
   and `gh pr diff <n>`. Read author comments (scope decisions live there) and the
   Codecov comment (baseline patch %, partials, project delta). Check mergeability
   with current base: `git merge-tree --write-tree HEAD upstream/main`.
2. **Classify.** `git diff <baseRefOid> -- <files> | grep '^-[^-]'`.
   - **Additive only** → lax review: polish the new code; don't chase edge cases.
   - **Modifies existing code** → rigorous: review every changed behavior, its callers,
     back-compat. Tell the user which it is.
3. **Run the PR's tests as-is** before touching anything.
4. **Fix the code — faithfully.** Allowed: bugs, typos, wrong labels/docstrings,
   misleading output, wrong exception types, module-level side effects (e.g. a new
   top-level import of an undeclared dependency → import lazily, as the module already
   does elsewhere). Anything that alters the PR's design (data flow, API shape, core
   behavior) needs the user's OK first. List every functional change in your summary.
5. **Match repo conventions** (see below).
6. **Tests.** Simplify setup, assert contract-level behavior. Run `/assess-tests`;
   drop performative tests. When simplifying fixtures, check you didn't drop a
   meaningful step from the original.
7. **Coverage.** `pytest <test> --cov=<module> --cov-branch --cov-report=term-missing`.
   Every new line/branch covered or justified. Cover gaps with real tests (caller-supplied
   arguments, non-default flags) — not guard-clause tests `/assess-tests` would reject.
   Compare to the Codecov baseline.
8. **Repo-specific steps** from `repos/<repo-name>.md`, if any.
9. **Verify.** Tests, the repo's linter/formatter, typecheck on new lines.
10. **Deliver.** Summary: review level, functional vs cosmetic changes, coverage vs
    baseline, anything left uncovered and why. Offer `/conventional-commit`.

## Repo conventions

Before writing anything, grep how the repo already does it and match: fixtures, import
style, library kwargs, type-hint style, exception types. Deviate only for
**wrong/inefficient, deprecation, or clarity** — and say which. "Discouraged" is not
"deprecated".

## Red flags — stop and reconsider

| Thought | Reality |
|---|---|
| "I'll improve the design while I'm here" | Ask first; stay truthful to the original. |
| "Re-add the guard test to recover coverage" | Cover real branches instead; report what stays uncovered. |
| "Newer idiom is better" | Repo convention wins unless wrong, deprecated, or clearer. |
| "Simplified the fixture" | Did you drop something meaningful? |
| "Tests pass, so it's done" | Check the repo file's criteria too. |
| "I'll commit it for them" | Never. Leave it uncommitted. |
