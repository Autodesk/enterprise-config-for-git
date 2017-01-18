#!/usr/bin/env bash
#
# Pull Git repositories including their submodules
#
# Usage: git <KIT_ID> pull
#
set -e

git pull --recurse-submodules $@
git submodule update --init --recursive
