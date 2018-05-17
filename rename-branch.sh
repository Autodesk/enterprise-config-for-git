#!/usr/bin/env bash
#/
#/ Rename a git branch, both locally and remotely (upstream on "origin").
#/
#/ Usage: git $KIT_ID new_branch <old_branch>
#/
#/    new_branch : New name for the branch
#/    old_branch : Branch to be renamed. If absent then rename the currently checked out branch
#/
#/ Example: git $KIT_ID rename my_new_branch my_old_branch
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/lib/setup_helpers.sh"

rename_branch()
{
    local old_branch_name new_branch_name
    if [ $# -eq 1 ]
    then
        new_branch_name=$1
        old_branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    elif [ $# -eq 2 ]
    then
        new_branch_name=$1
        old_branch_name=$2
    else
        print_usage
        exit 1
    fi

    echo "Renaming branch ${old_branch_name} to ${new_branch_name}"

    # Rename the local branch
    git branch -m ${old_branch_name} ${new_branch_name}

    # Push the newly named local branch onto the original name on the remote
    git push origin :${old_branch_name} ${new_branch_name}

    # Change the branch's upstream name
    git push -u origin ${new_branch_name}:${new_branch_name}
}

rename_branch "$@"
