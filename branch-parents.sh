#!/usr/bin/env bash
# Prints the inferred chain of parent branches for the current branch,
# closest first, e.g. "B1, B2, B, C, D, main".
#
# Usage: branch-parents.sh [repo-path] [base-branch]
#   repo-path    optional; passed to git via -C. Defaults to the current directory
#                (pass "" to skip it when you only want to set base-branch).
#   base-branch  optional; defaults to "main". Branches with no commits ahead of
#                it are ignored, except the base branch itself.
#
# Git does not store which branch a branch was created from, so this infers it:
# every local branch whose tip is an ancestor of the current branch is a
# candidate (this includes branches that were merged into it), ordered by how
# many commits they are behind the current branch.

path_var=${1:-$PWD}
base=${2:-main}

git -C "$path_var" rev-parse --git-dir >/dev/null || exit 1
git -C "$path_var" rev-parse --verify --quiet "refs/heads/$base" >/dev/null || {
  echo "Base branch '$base' not found" >&2
  exit 1
}

current=$(git -C "$path_var" symbolic-ref --short -q HEAD) || {
  echo "Not on a branch (detached HEAD)" >&2
  exit 1
}

declare -a dep_branches_info_arr=()

dep_branches_info_arr+=("BRANCH","COUNT_PULL_FROM","COUNT_AHEAD")
dep_branches_info_arr+=("","","")

declare -a dep_branches_arr=()

# while read -r branch; do
for branch in `git -C "$path_var" for-each-ref --format='%(refname:short)' refs/heads/`; do
  [[ "$branch" == "$current" ]] && continue
  # Skip branches with no commits ahead of the base (e.g. already merged into
  # it, or pointing at the same commit). The base itself is always kept.
  if [[ "$branch" != "$base" ]] && [[ "$(git -C "$path_var" rev-list --count "$base..$branch")" -eq 0 ]]; then
    continue
  fi

  is_acestor=$(git -C "$path_var" merge-base --is-ancestor "$branch" "$current");
  acestor_count=$(git -C "$path_var" rev-list --count "$current..$branch"); # How many commits can current pull from branch
  push_count=$(git -C "$path_var" rev-list --count "$branch..$current"); # How many commits are in branch and not in current

  $is_acestor && dep_branches_arr+=("$branch")

  $is_acestor && dep_branches_info_arr+=("$branch","$acestor_count","$push_count");
done

printf '%s\n' "${dep_branches_info_arr[@]}" | column -t -s ","