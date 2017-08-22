#!/usr/bin/env bash
#/
#/ Creates a new Git worktree one level above the current repo.
#/
#/ Usage: git $KIT_ID make-worktree <WORKTREE-NAME>
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/lib/setup_helpers.sh"

if [ $# -lt 1 ]; then
    error_exit "Please specify worktree name!"
fi

WORKTREE_NAME=$1
ROOT=$(git rev-parse --show-toplevel)
WORKTREE_PATH="$ROOT/../$WORKTREE_NAME"

if [ -d $WORKTREE_PATH ]; then
    error_exit "Worktree \"$WORKTREE_NAME\" already exists!"
fi

git worktree add -b $WORKTREE_NAME "$WORKTREE_PATH" HEAD

pushd "$WORKTREE_PATH"
    git submodule update --init --recursive
popd

print_success "Worktree \"$WORKTREE_NAME\" successfully created!"
