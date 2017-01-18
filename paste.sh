#!/usr/bin/env bash
#
# Paste code to GitHub's gist service
#
# Usage: git <KIT_ID> paste code.py
#
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

ADS_USER=$(git config --global adsk.github.account)
SERVER=$(git config --global adsk.github.server)

if [ -z "$ADS_USER" ]; then
  error_exit 'Username must not be empty!'
fi

if [ -z "$SERVER" ]; then
  error_exit 'Server must not be empty!'
fi

ADS_PASSWORD_OR_TOKEN="$(get_credentials $SERVER $ADS_USER)"

[ -z "$ADS_PASSWORD_OR_TOKEN" ] && echo "Could not obtain password or token" && exit 1
[ "$ADS_PASSWORD_OR_TOKEN" = "" ] && echo "Blank password or token" && exit 1

perl $KIT_PATH/lib/paste.pl \
    --user $ADS_USER \
    --token $ADS_PASSWORD_OR_TOKEN \
    --server $SERVER \
    $@
