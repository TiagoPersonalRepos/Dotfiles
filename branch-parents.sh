#!/usr/bin/env bash
# Prints the inferred chain of parent branches for the current branch,
# closest first, e.g. "B1, B2, B, C, D, main".
#
# Usage: branch-parents.sh [repo-path]
#   repo-path  optional; passed to git via -C. Defaults to the current directory.
#
# Git does not store which branch a branch was created from, so this infers it:
# every local branch whose tip is an ancestor of the current branch is a
# candidate (this includes branches that were merged into it), ordered by how
# many commits they are behind the current branch.

set -euo pipefail

git_cmd=(git)
if [[ $# -ge 1 && -n "$1" ]]; then
  git_cmd=(git -C "$1")
fi

"${git_cmd[@]}" rev-parse --git-dir >/dev/null || exit 1

current=$("${git_cmd[@]}" symbolic-ref --short -q HEAD) || {
  echo "Not on a branch (detached HEAD)" >&2
  exit 1
}

while read -r branch; do
  [[ "$branch" == "$current" ]] && continue
  if "${git_cmd[@]}" merge-base --is-ancestor "$branch" "$current"; then
    printf '%s %s\n' "$("${git_cmd[@]}" rev-list --count "$branch..$current")" "$branch"
  fi
done < <("${git_cmd[@]}" for-each-ref --format='%(refname:short)' refs/heads/) # | sort -k1,1n -k2,2 | cut -d' ' -f2- | paste -sd, - | sed 's/,/, /g'