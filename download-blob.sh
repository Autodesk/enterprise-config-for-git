#!/usr/bin/env bash
#/
#/ Download a Git object from GitHub via API
#/
#/ Usage: git $KIT_ID download-blob [org/repo] [git-object-id]
#/
set -e

KIT_PATH=$(dirname "$0")
. "$KIT_PATH/enterprise.constants"
. "$KIT_PATH/lib/setup_helpers.sh"

[ $# -eq 2 ] || error_exit 'Please provide "org/repo" and "Git Object ID" as parameters.'

SLUG=$1
OBJ_ID=$2

USER=$(git config --global adsk.github.account)
[ -z "$USER" ] && error_exit 'Username must not be empty!'

TOKEN="$(get_credentials $GITHUB_SERVER $USER)"
[ -z "$TOKEN" ] && error_exit "No credentials found. Run 'git adsk'!"

curl $CURL_RETRY_OPTIONS --silent --fail --user "$USER:$TOKEN" \
    -H "Accept: application/vnd.github.VERSION.raw" \
    https://$GITHUB_SERVER/api/v3/repos/$SLUG/git/blobs/$OBJ_ID
