#!/usr/bin/env bash
#
# Clean checkout of a branch/tag/commit including all submodules.
# Attention: This is going to delete all local changes!
#
# Usage: git <KIT_ID> clean-checkout <options> <branch>
#
# <options> will be passed to the git clean command, see git-clean reference
#           for available options (-d --force --quiet are passed by default)
# <branch>  is expected to be the last argument
#
# Example: git ask clean-checkout master
#
set -e

# check if there is at least one argument passed to the command
if [ $# -lt 1 ]; then
    echo "No branch/commit specified"
    exit 1
fi

# read branch and options from the arguments, branch is expected to be the last argument
REF=${!#}
OPTIONS=${@:1:$#-1}

# fetch latest changes from all remotes
git fetch --all --force

# check if the requested ref (branch/tag/commit) exists
if [ -z "$(git cat-file -t $REF)" ]; then
    echo "Specified ref '$REF' not found"
    exit 1
fi

# sync submodules in case submodule URLs have changed
git submodule sync --recursive

# reset repo to have a clean state that enables a checkout in the next step
git reset --hard HEAD

# checkout branch and update submodules
git checkout --force $REF
git submodule update --force --init --recursive

# clean up repo and submodules
git clean -d --force --quiet $OPTIONS
git submodule foreach git clean -d --force --quiet $OPTIONS
git submodule foreach git reset --hard HEAD
