#!/usr/bin/env bash
#
# Clone Git repositories and download Git LFS files in parallel.
# See more info here: https://github.com/github/git-lfs/issues/931
#
# Usage: git <KIT_ID> clone <repository URL> [<target directory>]
#
set -e

git-lfs clone --recursive $@

case $(uname -s) in
    CYGWIN_NT-*|MINGW??_NT*)
        powershell "$KIT_PATH/lib/win/sourcetree_add_commit_link_text.ps1"
        ;;
    Darwin)
        "$KIT_PATH/lib/osx/sourcetree_add_commit_link_text.sh"
        ;;
esac
