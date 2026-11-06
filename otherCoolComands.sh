code $(git status -su | awk '{ print $2 ;}')
git merge --ff-only --no-edit
git lg --author="iago"
git lg origin/main..HEAD  # TODO: study this one
git switch <>
git switch -
git switch -c <> # create branch

declare -a res_array=()
res_array+=("REPO","BRANCH","PUSH","PULL","ST","FATHER-PULL")
res_array+=("","","","","")
printf '%s\n' "${res_array[@]}" | column -t -s ","