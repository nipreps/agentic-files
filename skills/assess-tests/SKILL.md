---
name: assess-tests
description: >
  Audit newly written tests for quality. Use this after writing or modifying any test file.
  Checks two things: (1) whether each test verifies real behavior in context vs restating
  trivial implementation details, and (2) whether test names are concise vs overdescriptive.
  Invoke whenever the user asks to "assess", "review", or "check" tests, or after completing
  a task that added or changed tests.
---

# Assess Tests

First, identify which test files are new or modified in the current working tree:

```bash
git diff --name-only HEAD -- '**/test_*.py' 'test_*.py'
git ls-files --others --exclude-standard -- '**/test_*.py' 'test_*.py'
```

Only assess tests in those files. Do not inspect tests in unmodified files.
If no test files are new or changed, say so and stop.

Then review each **new or changed** test against two criteria.

## Criterion 1: Performative vs real

A test is **performative** if it:
- Verifies a guard clause (e.g. "None input doesn't crash", "no-op when flag is False")
- Restates how a built-in works (e.g. "dict.get returns default", "list.append adds item")
- Checks a trivial return value with no surrounding context (e.g. `assert foo() is None`)
- Duplicates coverage already present in another test via a different entry point

A test is **real** if it:
- Exercises a meaningful interaction between components
- Would catch a real regression that a code author might plausibly introduce
- Tests the contract from the caller's perspective, not the implementation's perspective

**When in doubt:** ask "if I deleted this test and introduced a realistic bug, would this test be the one to catch it?" If the answer is "probably not — another test would catch it first", it's performative.

## Criterion 2: Name length

Test names should name the scenario, not describe the assertion.

- **Too long:** `test_cli_populate_writes_value_into_config_extensions_namespace_via_set`
- **Right:** `test_cli_populate_writes_to_namespace`
- **Also fine:** `test_sentry_dsn`, `test_config_extend_applies`

Strip filler phrases: "is used when", "correctly handles", "successfully", "properly", "as expected", "in the case where".

## Output format

For each test, one line with explicit verdicts on both criteria:

```
test_name  [real | performative: <why>]  [name ok | rename → test_better_name]
```

Then a short summary: how many to drop, how many to rename, any both.
If everything passes, say so in one line.

## Example

```
test_cli_extend_args_are_parseable            real  name ok
test_cli_populate_then_workflow_reads_value   real  name ok
test_get_namespace_creates_lazily             performative: tests dict auto-creation  name ok
test_config_extend_does_not_override_user_set_value  real  rename → test_config_extend_preserves_user_value

2 issues: 1 to drop, 1 to rename.
```
