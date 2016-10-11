#!/bin/sh

# Copyright 2016 Autodesk Inc. http://www.autodesk.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


usage()
{
    cat << EOM
Usage: git adsk show-deleted [-h] [path]

A utility to list the files that have been deleted from the current
branch.

    path    - relative path to the directory to report on

OPTIONS
    -h      - Display this help and exit

EOM
}

while getopts ":h" OPTION; do
    case "$OPTION" in
        h) usage; exit 0;;
        ?) usage; exit 1;;
    esac
done

shift $(( $OPTIND - 1 ))

# Make sure the argument list is valid
if [[ $# > 1 ]]; then
    usage; exit 1;
fi

# make sure we are in a valid context
if git-rev-parse --is-inside-worktree > /dev/null; then

    RELATIVE_REPO_PATH="${GIT_PREFIX:-.}"
    if [[ -n $1 ]]; then
        RELATIVE_REPO_PATH="$RELATIVE_REPO_PATH/$1"
    fi

    # Show deleted files by diffing a sorted list of delete operations
    # with the list of files currently in the tree.  The diff parameters
    # suppress any lines that are new (in the tree) or the same in both commands
    diff --new-line-format="" --unchanged-line-format="" \
        <(git-log --name-only --pretty=format: --diff-filter=D -- "$RELATIVE_REPO_PATH" | sort -u) \
        <(git-ls-tree --name-only -r HEAD "$RELATIVE_REPO_PATH" | sort -u)

fi
