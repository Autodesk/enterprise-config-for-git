#!/usr/bin/env bash
#/
#/ Check if a commit-ish is included in another commit-ish
#/
#/ Usage: git $KIT_ID is-included <CHECK_COMMIT> [CHECK_HEAD]
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/lib/setup_helpers.sh"

if [ $# -lt 1 ]; then
    error_exit "Please define a commit-ish to check!"
fi
CHECK_COMMIT=$1

if [ $# -ge 2 ]; then
    CHECK_HEAD=$2
else
    CHECK_HEAD=HEAD
fi

if git merge-base --is-ancestor $CHECK_COMMIT $CHECK_HEAD; then
    print_success "$CHECK_COMMIT is included in $CHECK_HEAD!"
else
    error_exit "$CHECK_COMMIT is NOT included in $CHECK_HEAD!"
fi
