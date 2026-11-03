# AGENTS.md

`hardfoc/.github` holds the HardFOC organisation profile, the community files every repository inherits, the
`org/` scripts that keep repository settings consistent, and the HardFOC engineering standard in
[`standards/`](standards/README.md).

AI agents working here or in any HardFOC repository follow [`standards/agents.md`](standards/agents.md). Read it
first; it covers the `AGENTS.md` and skills layout, the definition of done, attribution, PR hygiene and the checks
to run before pushing.

## This repository

- `standards/`: the standard. A change to a rule comes with an ADR in `standards/adr/` and updates every page,
  checklist and config it touches ([how to change it](standards/README.md#changing-the-standard)).
- `standards/config/`: the org `.clang-format` and `.clang-tidy`. Change the naming rules here and in
  `standards/naming-and-style.md` together.
- `org/`: scripts that change GitHub settings. Agents do not run them with `--apply`; an org owner does.
- `profile/README.md`: the org profile page, written to the README standard in `standards/docs.md`.

## Checks before pushing

- Markdown: `markdownlint` with line length 120 (tables and code blocks exempt).
- Shell: `bash -n org/*.sh` and `shellcheck org/*.sh` when scripts change.
- JSON and YAML: `jq . org/*.json org/rulesets/*.json` and `yamllint .github/ISSUE_TEMPLATE`.
