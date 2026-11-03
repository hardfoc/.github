## Summary

<!-- What changes, in one or two sentences. -->

## Why

<!-- The problem this solves. Link the issue, spec or upstream PR. -->

## How verified

- [ ] CI green, including `CI gate / gate`
- [ ] Ran locally before pushing: <!-- host tests, doc snippets, lint, docs build; or "n/a" -->
- [ ] On target: <!-- board, what was run and observed; or "not verified on hardware" plus bench steps -->

## Standard

<!-- https://github.com/hardfoc/.github/blob/main/standards/README.md -->

- [ ] Follows the HardFOC engineering standard, or each deviation is listed here with the rule and its issue

## Checklist

- [ ] PR title is an imperative commit subject (it becomes the squash commit)
- [ ] One logical change; no unrelated edits
- [ ] README / `docs/` and Doxygen updated for any behaviour or API change
- [ ] `CHANGELOG.md` entry under `## [Unreleased]`; breaking changes under `### Breaking`
- [ ] Tests added or updated, including failure paths
- [ ] Submodule pins bumped where needed, linking the PR or release pulled in
- [ ] No secrets, credentials or private datasheet material; no attribution lines
