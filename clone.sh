#!/usr/bin/env bash
#/
#/ Fast clone a repository with Git LFS files and submodules.
#/
#/ Usage: git $KIT_ID clone <repository URL> [<target directory>]
#/

# c.f. https://github.com/github/git-lfs/issues/931
git-lfs clone --recursive "$@"
