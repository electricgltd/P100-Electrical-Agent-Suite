#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: create_pr.sh [-b branch-name] [-m commit-message] [-t title] [-d]

Helper to create a branch, commit changes (if any), push, and open a draft PR using gh.

Options:
  -b BRANCH    Branch name to create (default: pr/devcontainer-<timestamp>)
  -m MESSAGE   Commit message if committing staged changes (default: "chore: add devcontainer files")
  -t TITLE     PR title (default: same as commit message)
  -d           Create the PR as draft (default: on)
  -h           Show this help
USAGE
}

BRANCH=""
MSG="chore: add devcontainer files"
TITLE=""
DRAFT=true

while getopts ":b:m:t:dh" opt; do
  case ${opt} in
    b) BRANCH=${OPTARG} ;;
    m) MSG=${OPTARG} ;;
    t) TITLE=${OPTARG} ;;
    d) DRAFT=true ;;
    h) usage; exit 0 ;;
    :) echo "Error: -${OPTARG} requires an argument" >&2; usage; exit 1 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; usage; exit 1 ;;
  esac
done

if [ -z "$BRANCH" ]; then
  BRANCH="pr/devcontainer-$(date +%Y%m%d-%H%M%S)"
fi

if [ -z "$TITLE" ]; then
  TITLE="$MSG"
fi

echo "Preparing to create branch '$BRANCH' and push changes"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh (GitHub CLI) is required to create the draft PR. Please install and authenticate 'gh' first." >&2
  exit 2
fi

# Make sure we're on a clean working tree or that user intends to commit
if ! git diff --quiet || ! git diff --quiet --staged; then
  echo "There are local changes. These will be committed with message: $MSG"
  git add -A
  git commit -m "$MSG"
else
  echo "No local changes to commit. Creating branch from current HEAD."
fi

git checkout -b "$BRANCH"
git push -u origin "$BRANCH"

PR_CMD=(gh pr create --title "$TITLE" --body-file .pr_body.md)
if [ "$DRAFT" = true ]; then
  PR_CMD+=(--draft)
fi

echo "Running: ${PR_CMD[*]}"
"${PR_CMD[@]}"

echo "PR created. Visit the repository in your browser to review or continue working." 
