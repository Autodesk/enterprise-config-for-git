#!/bin/bash
#
# Git utility methods
#
#
# Available functions from script:
#
# get_branch_name                      gets the name of the currently checked out branch
# get_base_branch                      attempts to find the base branch (e.g. master or release/2019)
# branch_exist                         checks if branch passed in 1st parameter exists

get_branch_name() {
    git rev-parse --abbrev-ref HEAD
}

get_base_branch() {
    set +e
    local baseBranch=$(git config 'adsk.pr-base-default')
    set -e
    local currentBranch=$(get_branch_name)
    for branch in $(git config --get-regexp 'adsk\.pr-base-branch-' | sed 's/.* //'); do
        local branch=${branch#adsk.pr-base-branch-}
        shopt -s nocasematch
        case "$currentBranch" in
            *"$branch/"*)
            baseBranch=$branch
            break
            ;;
        esac
        shopt -u nocasematch
    done

    echo "$baseBranch"
}


branch_exist() {
    git rev-parse --verify $1 > /dev/null 2>&1
}
