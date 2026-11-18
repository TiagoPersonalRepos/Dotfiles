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

  # Holds the literal command "true" or "false" so `$is_acestor && ...` below works.
  # (Capturing the output with $(...) would only capture the empty stdout, and an
  # empty `$is_acestor` always succeeds, so non-ancestors were being included.)
  git -C "$path_var" merge-base --is-ancestor "$branch" "$current" && is_acestor=true || is_acestor=false
  acestor_count=$(git -C "$path_var" rev-list --count "$current..$branch"); # How many commits can current pull from branch
  push_count=$(git -C "$path_var" rev-list --count "$branch..$current"); # How many commits are in branch and not in current

  $is_acestor && dep_branches_arr+=("$branch")

  $is_acestor && dep_branches_info_arr+=("$branch","$acestor_count","$push_count");
done

printf '%s\n' "${dep_branches_info_arr[@]}" | column -t -s ","

exit

# ---------------------------------------------------------------------------
# Ancestry graph between the branches in dep_branches_arr (plus the current one).
#
# An edge  P -> C  means "P is an ancestor of C", drawn only for DIRECT links:
# if P is an ancestor of Z and Z of C (all in the list), the P -> C edge is
# implied and left out (a transitive reduction). Branches pointing at the same
# commit are merged into one node, labelled "A = B".
#
# Set GRAPH_FORMAT=dot for Graphviz output; the default is Mermaid.
# ---------------------------------------------------------------------------
graph_format=${GRAPH_FORMAT:-mermaid}

declare -a g_shas=()
declare -A g_label=()
for b in "$current" "${dep_branches_arr[@]}"; do
  s=$(git -C "$path_var" rev-parse "refs/heads/$b")
  if [[ -z "${g_label[$s]:-}" ]]; then
    g_shas+=("$s")
    g_label[$s]="$b"
  else
    g_label[$s]+=" = $b"
  fi
done

# g_anc["x,y"]=1 when commit x is a strict ancestor of commit y
declare -A g_anc=()
for x in "${g_shas[@]}"; do
  for y in "${g_shas[@]}"; do
    [[ "$x" != "$y" ]] && git -C "$path_var" merge-base --is-ancestor "$x" "$y" && g_anc["$x,$y"]=1
  done
done

declare -A g_id=()
for i in "${!g_shas[@]}"; do g_id[${g_shas[$i]}]="n$i"; done

declare -a g_edges=()
for x in "${g_shas[@]}"; do
  for y in "${g_shas[@]}"; do
    [[ -n "${g_anc[$x,$y]:-}" ]] || continue
    direct=1
    for z in "${g_shas[@]}"; do
      if [[ -n "${g_anc[$x,$z]:-}" && -n "${g_anc[$z,$y]:-}" ]]; then direct=0; break; fi
    done
    (( direct )) && g_edges+=("$x $y")
  done
done

echo
if [[ "$graph_format" == "dot" ]]; then
  echo "digraph branches {"
  echo "  rankdir=LR;"
  for s in "${g_shas[@]}"; do echo "  ${g_id[$s]} [label=\"${g_label[$s]}\"];"; done
  for e in "${g_edges[@]}"; do read -r x y <<<"$e"; echo "  ${g_id[$x]} -> ${g_id[$y]};"; done
  echo "}"
else
  echo "graph LR"
  for s in "${g_shas[@]}"; do echo "  ${g_id[$s]}[\"${g_label[$s]}\"]"; done
  for e in "${g_edges[@]}"; do read -r x y <<<"$e"; echo "  ${g_id[$x]} --> ${g_id[$y]}"; done
fi