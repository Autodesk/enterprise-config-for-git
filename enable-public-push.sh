#!/usr/bin/env bash
#/
#/ Override the Enterprise Config push protection feature configure in
#/ config.include.
#/
#/ Usage: git $KIT_ID enable-public-push <server/org/repo>
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"

REPO=$1
git config --global url.https://$REPO.pushInsteadOf https://$REPO
git config --global url.git@$REPO.pushInsteadOf git@$REPO

    cat << EOM
###
### Enterprise Config
###

Git push to public repo on "$REPO" enabled. Be careful and please respect the source code policy: $KIT_SOURCE_CODE_POLICY_URL

EOM
