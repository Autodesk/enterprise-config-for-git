#!/usr/bin/env bash
#/
#/ Checkout a Pull Request
#/
#/ Usage: git $KIT_ID copr <GitHub Pull Request number>
#/
#/ c.f. https://gist.github.com/gnarf/5406589#gistcomment-1243876
#/
set -e

git fetch --force --update-head-ok ${2:-origin} refs/pull/$1/head:pr/$1
git checkout pr/$1;
