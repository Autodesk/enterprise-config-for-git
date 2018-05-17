#!/usr/bin/env bash
#/
#/ Clone a Git repository without downloading any Git LFS content
#/
#/ Usage: git $KIT_ID clone-no-lfs <repository URL> [<target directory>]
#/

GIT_LFS_SKIP_SMUDGE=1 git clone --recursive "$@"
