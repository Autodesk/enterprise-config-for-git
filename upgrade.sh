#!/usr/bin/env bash
#/
#/ Upgrade Git
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

USERNAME=$(git config --global adsk.github.account)
[ -z "$USERNAME" ] && error_exit 'Username must not be empty!'
SERVER=$(git config --global adsk.github.server)
[ -z "$SERVER" ] && error_exit 'Server must not be empty!'
TOKEN="$(get_credentials $SERVER $USERNAME)"

install_git "$USERNAME" "$TOKEN" "$@"
