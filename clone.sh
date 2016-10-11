#!/usr/bin/env bash
#
# Clone Git repositories and download Git LFS files in parallel.
# See more info here: https://github.com/github/git-lfs/issues/931
#
# Usage: git <KIT_ID> clone <repository URL> [<target directory>]
#
set -e

git-lfs clone --recursive $@
