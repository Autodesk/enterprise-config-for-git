#!/usr/bin/env bash
#/
#/ Creates a new Git worktree next to the current repo folder
#/
#/ Usage: git $KIT_ID make-worktree <WORKTREE-NAME> [-b <BRANCH-NAME> [<COMMITISH>]]
#/
#/ With default parameters, the command creates an empty worktree first, 
#/ then runs 'git adsk make-branch' command and populates the
#/ worktree based on its results.
#/
#/ If optional param [-b <BRANCH-NAME>] is specified,
#/ it makes new worktree named <WORKTREE-NAME> and checkouts branch <BRANCH-NAME>.
#/ If <COMMITISH> is specified, starts <BRANCH-NAME> from it, otherwise defaults to HEAD.
#/
#/ E.g. git $KIT_ID make-worktree new-worktree -b new-branch origin/release/2019
#/   would create new-worktree and create new-branch starting at origin/release/2019.
#/
set -e

KIT_PATH="$(dirname "${BASH_SOURCE[0]}")"
. "$KIT_PATH/lib/setup_helpers.sh"

export ERROR_HELP_MESSAGE="Usage: git adsk make-worktree <WORKTREE-NAME> [-b <BRANCH-NAME> [<COMMITISH>]]"

if [ $# -lt 1 ]; then
    error_exit "Please specify worktree name!"
fi

WORKTREE_NAME=$1
if [[ -z "$WORKTREE_NAME" ]]; then
    error_exit "Worktree name can not be empty! Please, specify worktree name"
fi

BRANCH_NAME=""
COMMITISH=""
if [[ -n $2 ]]; then
    if [[ $2 = "-b" ]]; then
        if [[ -z $3 ]]; then
            error_exit "if param '-b' was specified, specify branch name too"
        fi
        BRANCH_NAME=$3
        COMMITISH=$4 # if not specified, Git will default to HEAD
    else
        error_exit "Unrecognized param $2"
    fi
fi

ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH="$ROOT/../$WORKTREE_NAME"

if [ -d "$WORKTREE_PATH" ]; then
    error_exit "Worktree \"$WORKTREE_NAME\" already exists!"
fi


if [[ -n "$BRANCH_NAME" ]]
then
    # create and populate worktree as specified
    git worktree add -b $BRANCH_NAME "$WORKTREE_PATH" $COMMITISH
else
    # create an empty worktree and checkout the branch interactively
    git worktree add --no-checkout --detach "$WORKTREE_PATH"
    pushd "$WORKTREE_PATH"
        if ! git adsk make-branch --no-local-repo-checks; then
            error_exit "Error during making branch"
        fi
    popd
fi

pushd "$WORKTREE_PATH"
    git submodule update --init --recursive
popd

print_success "Worktree \"$WORKTREE_NAME\" successfully created!"
