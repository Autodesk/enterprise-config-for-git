#!/usr/bin/env bash
set -e

KIT_PATH=$(dirname "$0")
VERSION="0.9"

echo "Enterprise Config $VERSION ($(git --git-dir="$KIT_PATH/.git" --work-tree="$KIT_PATH" rev-parse --short HEAD))"
