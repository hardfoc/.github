# Repository governance

How every HardFOC repository is set up and how changes reach `main`. The scripts named here are in
[`org/`](../org/README.md); each defaults to a dry run and takes `--repo NAME` to act on one repository.

## Branches

- `main` is the only long-lived branch. Nobody pushes to it; every change is a pull request.
- Work branches are named by kind, then a short topic in kebab case:

  | Prefix | For |
  | --- | --- |
  | `feat/<topic>` | New behaviour or API |
  | `fix/<topic>` | A bug fix |
  | `docs/<topic>` | Documentation only |
  | `ci/<topic>` | Workflows, lint and build configuration |
  | `chore/<topic>` | Pin bumps, version bumps, renames, housekeeping |
  | `release/x.y` | A maintenance line for an older minor (`release/0.1`), created from its tag by a maintainer, changed only by PR |

- Branches are deleted automatically when their PR merges (see [Merge settings](#merge-settings)).
- A submodule never points at an unmerged branch.

## Pull requests

- **Squash merge only**, and the PR title becomes the commit subject on `main`. Write the title as a commit
  subject: imperative, under about 72 characters, no trailing period (`Add BMP581 FIFO read`).
- **One logical change** per PR, ideally under about 400 lines of diff. Larger work is a series of PRs, each green.
- **The PR template** ([`.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md), inherited by every
  repository without its own) is filled in: summary, why, how it was verified (CI, host tests, which board), the
  checklist.
- **Docs and changelog in the same PR** as the code: the README or `docs/` page for any behaviour or API change, and
  an entry under `## [Unreleased]` in `CHANGELOG.md` ([release.md](release.md#changelog)).
- **A deviation from the standard** is named in the PR description with the rule and the tracking issue.
- **A pin bump** is its own PR that links the PR or release it pulls in and notes API or build-setting changes.
- **No attribution lines** in commits, PR descriptions, issues or comments: no `Co-Authored-By:` trailers for tools
  or agents, no "Generated with" footers. Authorship is the GitHub account that opened the PR.
- **Review**: one approving review from a code owner, and every conversation resolved. Org owners and repository
  admins may merge their own PR without a second reviewer, but only through a PR.

## Issues and labels

Issues use the org forms in [`.github/ISSUE_TEMPLATE/`](../.github/ISSUE_TEMPLATE): **Bug report**, **Driver
request** and **Feature request**. Blank issues are off; questions go to
[org-discussions](https://github.com/hardfoc/org-discussions), and vulnerabilities to a private security advisory
([SECURITY.md](../SECURITY.md)).

Every repository uses this label set:

| Label | Meaning |
| --- | --- |
| `bug` | Something behaves wrong (set by the bug form) |
| `enhancement` | New capability or API change (set by the feature form) |
| `driver-request` | A new chip driver (set by the driver request form) |
| `safety` | Can damage hardware or cause unsafe motion, heat or pressure; fixed before anything else |
| `breaking` | Changes a public API, a config layout or NVS; needs `### Breaking` in the changelog |
| `standard` | Brings the repository in line with this standard |
| `documentation` | Docs only |
| `ci` | Workflows and tooling |
| `dependencies` | Dependency and action updates (set by Dependabot) |
| `good first issue` | Small and well described |

Labels are created by hand when a repository is set up; there is no script for them yet.

## CODEOWNERS

GitHub has no org-wide CODEOWNERS, so each repository carries `.github/CODEOWNERS`:

```text
# Default reviewers for every path in this repository.
* @N3b3x
```

`org/add-codeowners.sh --repo NAME --apply` opens the PR that adds it. A repository started from a template
already has the file.

## Rulesets

[`org/apply-rulesets.sh`](../org/apply-rulesets.sh) applies the rulesets in [`org/rulesets/`](../org/rulesets) to
every public repository. The org is on GitHub Free, so rulesets are per repository and do not apply to private
repositories (the script lists those).

| Ruleset | Applies to | Rules | Bypass |
| --- | --- | --- | --- |
| `main-integrity` | default branch | no deletion, no force push, linear history | nobody |
| `main-review` | default branch | PR with one approving code-owner review, resolved conversations, squash only | org owners and repository admins, through a PR |
| `release-tags` | `v*.*.*` tags | no deletion, no moving | org owners |

### The required check

Every repository's CI ends in one gate job from the reusable `ru-ci-gate.yml`, named `CI gate`, so the single
required status check is always:

```text
CI gate / gate
```

The gate is added to the repository's ruleset only once the repository has the job, because a required check that
never runs blocks every PR. The `main-review` ruleset in `org/rulesets/` does not include it for that reason. To
require it on one repository, add a `required_status_checks` rule to that repository's `main-review` ruleset:

```json
{
  "type": "required_status_checks",
  "parameters": {
    "strict_required_status_checks_policy": false,
    "required_status_checks": [{ "context": "CI gate / gate" }]
  }
}
```

The gate MUST list every other job in `needs` and use `if: always()`; with `verify_needs: true` (the default) the
gate checks this itself.

## Security

[`org/apply-security.sh`](../org/apply-security.sh) turns on, for every public repository: secret scanning, push
protection, Dependabot alerts, Dependabot security updates, and private vulnerability reporting (the channel
[SECURITY.md](../SECURITY.md) points to). Private repositories need GitHub Advanced Security for these and are
skipped.

Workflows follow least privilege: `permissions: contents: read` at the top, wider permissions only on the job that
needs them, and no secrets in workflows triggered by forks.

## Dependabot

Every repository with workflows has `.github/dependabot.yml` for GitHub Actions; repositories with Python tooling
add `pip`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    labels: [dependencies]
    commit-message:
      prefix: "ci"
```

Dependabot does not manage submodules: it tracks branches, and HardFOC pins release tags. Submodule pins move
through the bump bot and pin-bump PRs ([release.md](release.md#pins-and-the-manifest)). Reusable workflows are
pinned to the major tag (`@v1`), which Dependabot leaves alone.

## Merge settings

[`org/apply-merge-settings.sh`](../org/apply-merge-settings.sh) turns on **Automatically delete head branches** in
every repository, public and private. Each repository also allows squash merging only, with the PR title as the
default commit title. The `main-review` ruleset enforces squash on public repositories; on private repositories it
is the repository setting alone.

## Metadata

[`org/org-metadata.json`](../org/org-metadata.json) holds every repository's description, homepage and topics,
and the portal's catalogue reads it. Change it by PR, then run `org/apply-metadata.sh --repo NAME --apply`. The
description templates and topic vocabulary are in [`org/README.md`](../org/README.md#editing-the-metadata).

## Creating a repository

1. **Create it from the template** for its kind, in the `hardfoc` org, public unless it is a product:

   ```bash
   gh repo create hardfoc/hf-<chip>-driver --public --template hardfoc/hf-driver-template
   gh repo clone hardfoc/hf-<chip>-driver && cd hf-<chip>-driver
   python3 tools/scaffold.py --kind driver --name <chip> --bus spi|i2c|uart|adc --description "..."
   ```

   The template carries the shell: CMake layout, CI workflows with the gate, `_config/` with the org configs,
   docs page set, `CODEOWNERS`, `AGENTS.md`, `CLAUDE.md` and `.claude/skills/`. The templates by kind:

   | Kind | Template | How |
   | --- | --- | --- |
   | Chip driver | [`hf-driver-template`](https://github.com/hardfoc/hf-driver-template) | `tools/scaffold.py --kind driver` |
   | Library (utils, rtos-wrap, interface-wrap) | [`hf-driver-template`](https://github.com/hardfoc/hf-driver-template) | `tools/scaffold.py --kind library` |
   | hf-core handler | `templates/handler/` in hf-core | its scaffold script, see hf-core `AGENTS.md` |
   | Board HAL | `templates/board-hal/` in [`hf-hal-common`](https://github.com/hardfoc/hf-hal-common) | `tools/scaffold/new_board_hal.py` |
2. **Add the metadata**: a PR to `hardfoc/.github` adding the repository to `org/org-metadata.json`. After it merges:

   ```bash
   ./org/apply-metadata.sh --repo hf-<chip>-driver --apply
   ```

3. **Apply the settings** (each script shows a dry run first without `--apply`):

   ```bash
   ./org/apply-merge-settings.sh --repo hf-<chip>-driver --apply
   ./org/apply-security.sh       --repo hf-<chip>-driver --apply   # public repositories
   ./org/apply-rulesets.sh       --repo hf-<chip>-driver --apply   # public repositories
   ./org/add-codeowners.sh       --repo hf-<chip>-driver --apply   # only if the template had no CODEOWNERS
   ```

4. **Create the labels** above.
5. **Require the gate** once the first CI run has produced `CI gate / gate` ([The required check](#the-required-check)).
6. **Wire it in**: add it as a submodule where it is consumed (`hf-core-drivers` for a driver) in a pin PR.

Then follow the checklist for its kind in [`checklists/`](checklists/).

## Archiving

A repository that is superseded gets the `legacy` topic and a `[Legacy] ... superseded by <repo>.` description in
the metadata, a README note pointing to its successor, and is archived. Archived repositories are skipped by every
script.
