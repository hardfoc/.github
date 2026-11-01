#!/usr/bin/env bash
# Open one PR per repo adding .github/CODEOWNERS ("* @<owner>").
#
# CODEOWNERS cannot be set org-wide, so each repo needs its own file. Default
# is a dry run that lists what would happen. --apply clones each repo
# (shallow, no submodules), commits on branch chore/codeowners, pushes and
# opens a PR. Repos that already have a CODEOWNERS file or the branch are
# skipped, so re-running is safe.
#
# Requires: gh (authenticated with push access), git, jq.

set -euo pipefail

ORG="hardfoc"
BRANCH="chore/codeowners"
OWNER=""
MODE="dry-run"
WORKDIR="${TMPDIR:-/tmp}/hardfoc-codeowners"
EXCLUDE=(hf-hal-vortex-v1 hf-hal-flux-v1 hardfoc-vortex-v1 hardfoc-flux-v1 hf-tmc5160-driver)
ONLY=()

usage() {
  cat <<'EOF'
Usage: org/add-codeowners.sh [--dry-run | --apply] [options]

  --dry-run         List repos and what would be done (default).
  --apply           Create branch, commit, push and open PRs.
  --owner LOGIN     Code owner (default: the authenticated gh user).
  --workdir DIR     Where to clone (default: $TMPDIR/hardfoc-codeowners).
  --exclude NAME    Additional repo to skip. Repeatable.
  --repo NAME       Only process NAME. Repeatable.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --apply) MODE="apply" ;;
    --owner) OWNER="${2:?}"; shift ;;
    --workdir) WORKDIR="${2:?}"; shift ;;
    --exclude) EXCLUDE+=("${2:?}"); shift ;;
    --repo) ONLY+=("${2:?}"); shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -n "$OWNER" ]] || OWNER="$(gh api user --jq .login)"

in_list() {
  local needle="$1"; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

echo "org: ${ORG}   owner: @${OWNER}   mode: ${MODE}"
mkdir -p "$WORKDIR"

opened=()
while IFS=$'\t' read -r repo default_branch; do
  if [[ ${#ONLY[@]} -gt 0 ]] && ! in_list "$repo" "${ONLY[@]}"; then continue; fi
  if in_list "$repo" "${EXCLUDE[@]}"; then echo "skip  ${repo}: excluded"; continue; fi

  existing=""
  for p in .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS; do
    if gh api "repos/${ORG}/${repo}/contents/${p}?ref=${default_branch}" >/dev/null 2>&1; then existing="$p"; break; fi
  done
  if [[ -n "$existing" ]]; then echo "skip  ${repo}: already has ${existing}"; continue; fi

  if gh api "repos/${ORG}/${repo}/branches/${BRANCH}" >/dev/null 2>&1; then
    pr="$(gh pr list --repo "${ORG}/${repo}" --head "$BRANCH" --state all --json url --jq '.[0].url // ""')"
    echo "skip  ${repo}: branch ${BRANCH} exists ${pr}"
    continue
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    echo "todo  ${repo}: would open PR ${BRANCH} -> ${default_branch}"
    continue
  fi

  dir="${WORKDIR}/${repo}"
  rm -rf "$dir"
  git clone -q --depth 1 --branch "$default_branch" "https://github.com/${ORG}/${repo}.git" "$dir"
  git -C "$dir" checkout -q -b "$BRANCH"
  mkdir -p "${dir}/.github"
  printf '# Default reviewers for every path in this repository.\n* @%s\n' "$OWNER" > "${dir}/.github/CODEOWNERS"
  git -C "$dir" add .github/CODEOWNERS
  git -C "$dir" commit -q -m "Add CODEOWNERS" \
    -m "CODEOWNERS cannot be set at the org level. Request review from the maintainer on every PR by default."
  git -C "$dir" push -q -u origin "$BRANCH"
  url="$(gh pr create --repo "${ORG}/${repo}" --base "$default_branch" --head "$BRANCH" \
    --title "Add CODEOWNERS" \
    --body "Adds \`.github/CODEOWNERS\` with \`* @${OWNER}\` so every PR requests review from the maintainer by default. GitHub has no org-wide CODEOWNERS, so each repo carries its own file.")"
  echo "done  ${repo}: ${url}"
  opened+=("$url")
done < <(gh repo list "$ORG" --limit 200 --no-archived \
          --json name,defaultBranchRef,isEmpty \
          --jq '.[] | select(.isEmpty | not) | [.name, .defaultBranchRef.name] | @tsv' | sort)

echo
echo "opened ${#opened[@]} PR(s)"
if [[ ${#opened[@]} -gt 0 ]]; then printf '%s\n' "${opened[@]}"; fi
