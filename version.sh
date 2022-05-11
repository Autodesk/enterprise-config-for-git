#!/usr/bin/env bash
set -e

KIT_PATH=$(dirname "$0")

echo "Enterprise Config $(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" describe --always --tags --dirty)"
