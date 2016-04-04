#!/usr/bin/env bash
#
# Clone Git repositories and download Git LFS files in parallel.
# See more info here: https://github.com/github/git-lfs/issues/931
#
# Usage: git adsk clone <repository URL> [<target directory>]
#
set -e

git -c filter.lfs.smudge=cat clone --recursive $@
if [[ -z $2 ]]; then
    CLONE_PATH=$(basename ${1%.git});
else
    CLONE_PATH=$2;
fi
cd "$CLONE_PATH"
git-lfs pull
