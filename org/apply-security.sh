#!/usr/bin/env bash
# Turn on GitHub's free security features for every public, non-archived repo
# in the org:
#   - secret scanning and push protection
#   - Dependabot alerts and Dependabot security updates
#   - private vulnerability reporting (the channel SECURITY.md points to)
#
# Default is a dry run that reports each repo's current state. Pass --apply to
# enable whatever is off. Re-running is safe. Private repos are skipped: on the
# org's plan these features need GitHub Advanced Security there.
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
    -h|--help) echo "Usage: org/apply-security.sh [--dry-run | --apply] [--repo NAME]..."; exit 0 ;;
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
    --no-archived --json name,visibility -q '.[] | select(.visibility == "PUBLIC") | .name' | sort)
fi

state() {
  local repo="$1"
  local sa alerts pvr
  sa="$(gh api "repos/${ORG}/${repo}" -q '[.security_and_analysis.secret_scanning.status // "off",
        .security_and_analysis.secret_scanning_push_protection.status // "off",
        .security_and_analysis.dependabot_security_updates.status // "off"] | join(" ")')"
  if gh api "repos/${ORG}/${repo}/vulnerability-alerts" >/dev/null 2>&1; then alerts="enabled"; else alerts="disabled"; fi
  pvr="$(gh api "repos/${ORG}/${repo}/private-vulnerability-reporting" -q 'if .enabled then "enabled" else "disabled" end' 2>/dev/null || echo disabled)"
  echo "$sa $alerts $pvr"
}

printf '%-28s %-9s %-9s %-9s %-9s %-9s\n' repo secrets push-prot dep-alert dep-fixes vuln-rep
for repo in "${REPOS[@]}"; do
  read -r secret push fixes alerts pvr <<<"$(state "$repo")"
  if [[ $MODE == apply ]]; then
    [[ $alerts == enabled ]] || gh api -X PUT "repos/${ORG}/${repo}/vulnerability-alerts" >/dev/null
    [[ $fixes == enabled ]] || gh api -X PUT "repos/${ORG}/${repo}/automated-security-fixes" >/dev/null
    if [[ $secret != enabled || $push != enabled ]]; then
      gh api -X PATCH "repos/${ORG}/${repo}" --input - >/dev/null <<'JSON'
{"security_and_analysis": {"secret_scanning": {"status": "enabled"},
                           "secret_scanning_push_protection": {"status": "enabled"}}}
JSON
    fi
    [[ $pvr == enabled ]] || gh api -X PUT "repos/${ORG}/${repo}/private-vulnerability-reporting" >/dev/null
    read -r secret push fixes alerts pvr <<<"$(state "$repo")"
  fi
  printf '%-28s %-9s %-9s %-9s %-9s %-9s\n' "$repo" "$secret" "$push" "$alerts" "$fixes" "$pvr"
done
