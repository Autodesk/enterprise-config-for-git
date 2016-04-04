#!/usr/bin/env bash
#
# Override the Enterprise Config push protection feature configure in
# config.include.
#
# Usage: git adsk enable-public-push <server/org/repo>
#
set -e

REPO=$1
git config --global url.https://$REPO.pushInsteadOf https://$REPO
git config --global url.git@$REPO.pushInsteadOf git@$REPO

    cat << EOM
###
### Enterprise Config
###

Git push to public repo on "$REPO" enabled. Be careful and please respect the source code policy!

EOM

