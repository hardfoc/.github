#!/usr/bin/env bash
# Apply repository metadata (description, homepage, topics) to the hardfoc org
# from org-metadata.json.
#
# Default is a dry run: it prints, per repo, what differs between GitHub and
# the JSON and changes nothing. Pass --apply to write the differences.
# Re-running is safe: repos that already match are reported as "ok" and left
# untouched.
#
# Requires: gh (authenticated as an org admin), jq.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="${SCRIPT_DIR}/org-metadata.json"
MODE="dry-run"
INCLUDE_SKIPPED=0
ONLY=()

usage() {
  cat <<'EOF'
Usage: org/apply-metadata.sh [--dry-run | --apply] [options]

  --dry-run          Show current vs desired metadata per repo (default).
  --apply            Write description, homepage and topics where they differ.
  --file PATH        Metadata file (default: org/org-metadata.json).
  --repo NAME        Only process NAME. Repeatable.
  --include-skipped  Also process entries marked "skip": true.
  -h, --help         Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --apply) MODE="apply" ;;
    --file) FILE="${2:?--file needs a path}"; shift ;;
    --repo) ONLY+=("${2:?--repo needs a name}"); shift ;;
    --include-skipped) INCLUDE_SKIPPED=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

for tool in gh jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing required tool: $tool" >&2; exit 1; }
done
[[ -f "$FILE" ]] || { echo "metadata file not found: $FILE" >&2; exit 1; }

ORG="$(jq -r '.org' "$FILE")"
[[ -n "$ORG" && "$ORG" != "null" ]] || { echo "metadata file has no .org" >&2; exit 1; }

wanted() {
  local name="$1"
  [[ ${#ONLY[@]} -eq 0 ]] && return 0
  local o
  for o in "${ONLY[@]}"; do [[ "$o" == "$name" ]] && return 0; done
  return 1
}

n_ok=0; n_diff=0; n_applied=0; n_skipped=0; n_missing=0

echo "org: ${ORG}   mode: ${MODE}   file: ${FILE}"
echo

while IFS= read -r entry; do
  repo="$(jq -r '.repo' <<<"$entry")"
  wanted "$repo" || continue

  if [[ "$(jq -r '.skip // false' <<<"$entry")" == "true" && $INCLUDE_SKIPPED -eq 0 ]]; then
    echo "== ${repo}: skipped ($(jq -r '.skip_reason // "marked skip"' <<<"$entry"))"
    n_skipped=$((n_skipped + 1))
    continue
  fi

  want_desc="$(jq -r '.description // ""' <<<"$entry")"
  want_home="$(jq -r '.homepage // ""' <<<"$entry")"
  want_topics="$(jq -c '[.topics[]?] | unique' <<<"$entry")"

  if ! current="$(gh api "repos/${ORG}/${repo}" \
      --jq '{d: (.description // ""), h: (.homepage // ""), t: ((.topics // []) | unique)}' 2>/dev/null)"; then
    echo "== ${repo}: NOT FOUND (or no access)"
    n_missing=$((n_missing + 1))
    continue
  fi
  cur_desc="$(jq -r '.d' <<<"$current")"
  cur_home="$(jq -r '.h' <<<"$current")"
  cur_topics="$(jq -c '.t' <<<"$current")"

  changes=()
  [[ "$cur_desc" != "$want_desc" ]] && changes+=(description)
  [[ "$cur_home" != "$want_home" ]] && changes+=(homepage)
  [[ "$cur_topics" != "$want_topics" ]] && changes+=(topics)

  if [[ ${#changes[@]} -eq 0 ]]; then
    echo "== ${repo}: ok"
    n_ok=$((n_ok + 1))
    continue
  fi

  n_diff=$((n_diff + 1))
  echo "== ${repo}: ${changes[*]}"
  for c in "${changes[@]}"; do
    case "$c" in
      description)
        echo "   description"
        echo "     - ${cur_desc}"
        echo "     + ${want_desc}" ;;
      homepage)
        echo "   homepage"
        echo "     - ${cur_home:-<empty>}"
        echo "     + ${want_home:-<empty>}" ;;
      topics)
        added="$(jq -rn --argjson c "$cur_topics" --argjson w "$want_topics" '($w - $c) | join(" ")')"
        removed="$(jq -rn --argjson c "$cur_topics" --argjson w "$want_topics" '($c - $w) | join(" ")')"
        echo "   topics"
        [[ -n "$removed" ]] && echo "     - ${removed}"
        [[ -n "$added" ]] && echo "     + ${added}" ;;
    esac
  done

  if [[ "$MODE" == "apply" ]]; then
    if [[ " ${changes[*]} " == *" description "* || " ${changes[*]} " == *" homepage "* ]]; then
      gh repo edit "${ORG}/${repo}" --description "$want_desc" --homepage "$want_home" >/dev/null
    fi
    if [[ " ${changes[*]} " == *" topics "* ]]; then
      jq -n --argjson t "$want_topics" '{names: $t}' \
        | gh api -X PUT "repos/${ORG}/${repo}/topics" --input - >/dev/null
    fi
    echo "   applied"
    n_applied=$((n_applied + 1))
  fi
done < <(jq -c '.repos[]' "$FILE")

echo
echo "summary: ok=${n_ok} differs=${n_diff} applied=${n_applied} skipped=${n_skipped} missing=${n_missing}"
if [[ "$MODE" == "dry-run" && $n_diff -gt 0 ]]; then
  echo "dry run only; re-run with --apply to write these changes."
fi
