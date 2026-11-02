#!/usr/bin/env bash
# Make GitHub delete a pull request's head branch when the pull request merges,
# in every non-archived repo in the org (public and private). GitHub retargets
# open pull requests based on that branch to its base before deleting it, so
# stacked pull requests keep working.
#
# Default is a dry run that reports each repo's current state. Pass --apply to
# turn the setting on where it is off. Re-running is safe.
#
# Requires: gh (authenticated as an org owner).

set -euo pipefail

ORG="hardfoc"
MODE="dry-run"
ONLY=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --apply) MODE="apply" ;;
    --repo) ONLY+=("${2:?--repo needs a name}"); shift ;;
    -h|--help) echo "Usage: org/apply-merge-settings.sh [--dry-run | --apply] [--repo NAME]..."; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# Plain loops instead of mapfile: macOS ships bash 3.2.
REPOS=()
if ((${#ONLY[@]})); then
  REPOS=("${ONLY[@]}")
else
  while IFS= read -r name; do REPOS+=("$name"); done < <(gh repo list "$ORG" --limit 500 \
    --no-archived --json name -q '.[].name' | sort)
fi

printf '%-28s %s\n' repo delete-branch-on-merge
for repo in "${REPOS[@]}"; do
  on="$(gh api "repos/${ORG}/${repo}" -q '.delete_branch_on_merge')"
  if [[ $MODE == apply && $on != true ]]; then
    on="$(gh api -X PATCH "repos/${ORG}/${repo}" -F delete_branch_on_merge=true -q '.delete_branch_on_merge')"
  fi
  printf '%-28s %s\n' "$repo" "$on"
done
