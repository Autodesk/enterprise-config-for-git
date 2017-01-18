#!/usr/bin/env bash
#
# Eases the installation of git adsk like this:
# curl --user '<YOUR-USER>:<YOUR-PASSWORD>' https://git.autodesk.com/raw/github-solutions/adsk-git/master/install.sh | sh
#
git clone --branch production https://git.autodesk.com/github-solutions/adsk-git.git ~/.adsk-git
git config --global include.path ~/.adsk-git/config.include
