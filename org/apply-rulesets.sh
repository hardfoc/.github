#!/usr/bin/env bash
# Apply the repository rulesets in org/rulesets/*.json to every public,
# non-archived repo in the org. The org is on GitHub Free, where org-level
# rulesets are unavailable and rulesets work on public repos only, so each
# repo gets its own copy; private repos are listed and skipped.
#
# Default is a dry run: per repo it reports which rulesets would be created
# or updated. Pass --apply to write them. Re-running is safe: rulesets are
# matched by name and updated in place.
#
# Requires: gh (authenticated as an org owner), jq.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORG="hardfoc"
MODE="dry-run"
ONLY=()

usage() {
  cat <<'USAGE'
Usage: org/apply-rulesets.sh [--dry-run | --apply] [--repo NAME]...

  --dry-run    Show what would change (default).
  --apply      Create or update the rulesets.
  --repo NAME  Only process NAME. Repeatable.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --apply) MODE="apply" ;;
    --repo) ONLY+=("${2:?--repo needs a name}"); shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

RULESETS=("${SCRIPT_DIR}"/rulesets/*.json)

# Plain loops instead of mapfile: macOS ships bash 3.2.
REPOS=()
if ((${#ONLY[@]})); then
  REPOS=("${ONLY[@]}")
else
  while IFS= read -r name; do REPOS+=("$name"); done < <(gh repo list "$ORG" --limit 500 \
    --no-archived --json name,visibility -q '.[] | select(.visibility == "PUBLIC") | .name' | sort)
  echo "Private repos (not protectable on this plan):"
  gh repo list "$ORG" --limit 500 --no-archived \
    --json name,visibility -q '.[] | select(.visibility != "PUBLIC") | "  " + .name'
fi

# Repos the owner manages by hand; name them with --repo to include them.
SKIP=" hf-tmc5160-driver "

for repo in "${REPOS[@]}"; do
  if ((${#ONLY[@]} == 0)) && [[ $SKIP == *" $repo "* ]]; then
    printf '%-32s skipped (managed by hand)\n' "$repo"
    continue
  fi
  existing="$(gh api "repos/${ORG}/${repo}/rulesets" -q '.[] | "\(.name)\t\(.id)"' 2>/dev/null || true)"
  for file in "${RULESETS[@]}"; do
    name="$(jq -r .name "$file")"
    id="$(awk -F'\t' -v n="$name" '$1 == n {print $2}' <<<"$existing")"
    if [[ -n $id ]]; then action="update"; else action="create"; fi
    if [[ $MODE == dry-run ]]; then
      printf '%-32s %-16s would %s\n' "$repo" "$name" "$action"
      continue
    fi
    if [[ $action == update ]]; then
      gh api -X PUT "repos/${ORG}/${repo}/rulesets/${id}" --input "$file" >/dev/null
    else
      gh api -X POST "repos/${ORG}/${repo}/rulesets" --input "$file" >/dev/null
    fi
    printf '%-32s %-16s %sd\n' "$repo" "$name" "$action"
  done
done
