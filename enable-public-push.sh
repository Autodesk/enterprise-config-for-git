#!/usr/bin/env bash
#/
#/ Override the Enterprise Config push protection
#/ feature configured in config.include.
#/
#/ Usage: git $KIT_ID enable-public-push <server/org/repo>
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

if [ -z $1 ]; then
    error_exit \
    'A repository URL (without the "http(s)://" prefix) is required.
  Please try copying and pasting the command line suggested in the
  error message when you attempted to push to a public-facing Git
  service.'
fi

REPO=$1
git config --global url.https://$REPO.pushInsteadOf https://$REPO
git config --global url.git@$REPO.pushInsteadOf git@$REPO

    cat << EOM
###
### Enterprise Config
###

Git push to public repo on "$REPO" enabled. Be careful and please respect the source code policy: $KIT_SOURCE_CODE_POLICY_URL

EOM
