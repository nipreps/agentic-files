# agentic-files

A shared collection of agentic skills, subagents, slash commands, and related
configuration for developers working on [NiPreps](https://www.nipreps.org/)
projects (e.g. *fMRIPrep*, *sMRIPrep*, *MRIQC*, *NiBabies*, *dMRIPrep*,
*niworkflows*, *nitransforms*, …).

The goal is to give NiPreps contributors a common, version-controlled place to
store and reuse agent definitions across coding assistants — so that knowledge
about how to navigate, test, and contribute to the NiPreps ecosystem doesn't
have to be reinvented in each developer's local setup.

## Scope

This repository is intentionally agent-agnostic. Files here are intended to be
consumed by tools such as:

- [Claude Code](https://docs.claude.com/en/docs/claude-code) — skills, subagents, slash commands, hooks, settings
- [GitHub Copilot CLI](https://docs.github.com/en/copilot) and Copilot in IDEs
- [Gemini CLI](https://github.com/google-gemini/gemini-cli)
- [Codex](https://github.com/openai/codex) and other agentic coding tools

Where possible, prefer formats that are portable across agents (plain Markdown
skill files, prompt templates, etc.). When a file is specific to a single tool,
note that in its frontmatter or filename.

## Layout

The repository is organized by artifact type. Suggested top-level directories
(create as needed):

```
skills/      # Reusable, self-contained skills (Markdown with frontmatter)
agents/      # Subagent definitions
hooks/       # Hook scripts and configuration snippets
prompts/     # Standalone prompt templates
settings/    # Example settings.json fragments
```

Each artifact should be discoverable on its own — include a short
`description` in the frontmatter explaining when it applies, and prefer one
concept per file.

## Using these files

Most NiPreps repositories look for an `.agents/` directory at their root. A
common pattern is to vendor selected files from this repository into a
project's `.agents/` (or a tool-specific path such as `.claude/`,
`.github/copilot/`, etc.) — either by copying, by `git submodule`, or by a
small sync script.

Pick whichever mechanism fits the downstream project; this repo does not
prescribe one.

## Contributing

1. Add or update a file under the appropriate directory.
2. Keep skills focused and composable — prefer several small skills over one
   large one.
3. Document any NiPreps-specific assumptions (BIDS layouts, datalad usage,
   CircleCI workflows, expected test fixtures, etc.) inside the artifact
   itself, so it remains useful when loaded in isolation.
4. Open a pull request against `main`.

## License

Unless otherwise noted in an individual file, contents are released under the
same license terms as the broader NiPreps project. See `LICENSE` (to be added)
for details.
