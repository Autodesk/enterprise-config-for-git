#!/usr/bin/env bash
#
# Checkout a branch and update submodules accordingly
#
# Usage: git <KIT_ID> checkout <branch>
#
set -e

git checkout $@
git submodule update --recursive
