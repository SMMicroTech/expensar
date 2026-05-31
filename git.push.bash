#!/usr/bin/env bash

set -euo pipefail

commit_message="Auto commit"

branch_name="$(git rev-parse --abbrev-ref HEAD)"

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "$commit_message"
fi

if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  git push
else
  git push --set-upstream origin "$branch_name"
fi
