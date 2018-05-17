#!/usr/bin/env bash
#/
#/ Upload a file as a GitHub gist
#/
#/ Usage: git $KIT_ID paste <filename>
#/
#/ Example: git $KIT_ID paste code.py
#/
set -e

KIT_PATH=$(dirname "$0")

# shellcheck source=./enterprise.constants
. "$KIT_PATH/enterprise.constants"

# shellcheck source=./lib/setup_helpers.sh
. "$KIT_PATH/lib/setup_helpers.sh"

ADS_USER=$(git config --global adsk.github.account)
SERVER=$(git config --global adsk.github.server)

if [ -z "$ADS_USER" ]; then
  error_exit 'Username must not be empty!'
fi

if [ -z "$SERVER" ]; then
  error_exit 'Server must not be empty!'
fi

ADS_PASSWORD_OR_TOKEN=$(get_credentials "$SERVER" "$ADS_USER")

[ -z "$ADS_PASSWORD_OR_TOKEN" ] && echo "Could not obtain password or token" && exit 1
[ "$ADS_PASSWORD_OR_TOKEN" = "" ] && echo "Blank password or token" && exit 1

perl "$KIT_PATH/lib/paste.pl" \
    --user "$ADS_USER" \
    --token "$ADS_PASSWORD_OR_TOKEN" \
    --server "$SERVER" \
    "$@"
