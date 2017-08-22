#!/bin/sh
#/
#/ A utility to list the files that have been deleted from the current
#/ branch.
#/
#/ Usage: git $KIT_ID show-deleted [-h] [path]
#/
#/     path    - relative path to the directory to report on
#/
#/ OPTIONS
#/     -h      - Display this help and exit
#/

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"

usage()
{
    grep '^#/' <"$0" | cut -c 4- | sed "s/\$KIT_ID/$KIT_ID/"
}

while getopts ":h" OPTION; do
    case "$OPTION" in
        h) usage; exit 0;;
        ?) usage; exit 1;;
    esac
done

shift $(( $OPTIND - 1 ))

# Make sure the argument list is valid
if [ $# -gt 1 ]; then
    usage; exit 1;
fi

# make sure we are in a valid context
if git-rev-parse --is-inside-worktree > /dev/null; then

    RELATIVE_REPO_PATH="${GIT_PREFIX:-.}"
    if [ -n "$1" ]; then
        RELATIVE_REPO_PATH="$RELATIVE_REPO_PATH/$1"
    fi

    # Show deleted files by diffing a sorted list of delete operations
    # with the list of files currently in the tree.  The diff parameters
    # suppress any lines that are new (in the tree) or the same in both commands
    diff --new-line-format="" --unchanged-line-format="" \
        <(git-log --name-only --pretty=format: --diff-filter=D -- "$RELATIVE_REPO_PATH" | sort -u) \
        <(git-ls-tree --name-only -r HEAD "$RELATIVE_REPO_PATH" | sort -u)

fi
