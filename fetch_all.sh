#!/bin/bash

PROJ_HOME=~/SomeFolder

declare -a repo_array=(
    "some-repo"
)

declare -a res_array=()

res_array+=("REPO","BRANCH","PUSH","PULL","ST")
res_array+=("","","","")

father_branch="main"

for repo in "${repo_array[@]}"; do
    if [ -d $PROJ_HOME/$repo ]; then
    
        current_st=$(git -C $PROJ_HOME/$repo status -su | wc -l)

        repo_name=$(basename `git -C $PROJ_HOME/$repo rev-parse --show-toplevel`)
        current_branch=$(git -C $PROJ_HOME/$repo branch --show-current)

        if [ $1 ]; then
            git -C $PROJ_HOME/$repo fetch --all -q
        fi

        push_count=$(git -C $PROJ_HOME/$repo rev-list --count @{upstream}..$current_branch)
        pull_count=$(git -C $PROJ_HOME/$repo rev-list --count $current_branch..@{upstream})

        if [ $pull_count -ne 0 ]; then
            if [ $2 ]; then
                echo ""
                echo "-------------------------------------------------"
                echo "Attempt ff-merge: "$repo_name" "$current_branch
                git -C $PROJ_HOME/$repo merge --ff-only --no-edit
            fi
        fi
        # if [ $(git -C $PROJ_HOME/$repo ls-remote --heads origin refs/heads/$father_branch | wc -l) -eq 1 ]; then
        #     if [ $current_st -eq 0 ]; then

        #         git -C $PROJ_HOME/$repo switch $father_branch

                # father_ctpull=$(git -C $PROJ_HOME/$repo rev-list --count $(git -C $PROJ_HOME/$repo branch --show-current)..@{upstream})

        #         # TODO: flag
        #         # if [ $father_ctpull -ne 0 ]; then
        #         #     git -C $PROJ_HOME/$repo pull origin
        #         # fi

        #         git -C $PROJ_HOME/$repo switch -q -
        #         # TODO: confirm if merge is fast forward and if so merge
        #     fi
        # fi


        push_count_str=$( [ $push_count -eq 0 ] && echo "" || echo $push_count )
        pull_count_str=$( [ $pull_count -eq 0 ] && echo "" || echo $pull_count )
        current_st_str=$( [ $current_st -eq 0 ] && echo "" || echo $current_st )

        # "REPO","BRANCH","PUSH","PULL","ST"
        res_array+=("$repo_name","$current_branch","$push_count_str","$pull_count_str","$current_st_str")
    
    else
        echo "Not found: "$PROJ_HOME/$repo
    fi

done

printf '%s\n' "${res_array[@]}" | column -t -s ","