#!/usr/bin/env bash
#/
#/ Pull changes from a repository and all its submodules
#/
#/ Usage: git $KIT_ID pull
#/
set -e

git pull --recurse-submodules "$@"
