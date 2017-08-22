#!/usr/bin/env bash
#
# Eases the installation of git adsk like this:
# curl --user '<YOUR-USER>:<YOUR-PASSWORD>' https://<server>/raw/<org>/<repo>/master/install.sh | sh
#
git clone --branch production https://<server>/<org>/<repo>.git ~/.enterprise
git config --global include.path ~/.enterprise/config.include
