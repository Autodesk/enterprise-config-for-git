#!/usr/bin/env bash
#/
#/ Print "git $KIT_ID" version
#/
set -e

KIT_PATH=$(dirname "$0")
GIT_HASH=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" rev-parse --short HEAD)
GIT_TAG=$(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" tag --points-at HEAD)

echo "Enterprise Config $GIT_TAG ($GIT_HASH)"
